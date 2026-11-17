import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'all_owned_media.dart';
import 'app_core.dart';
import 'details.dart';
import 'library_organization_studio.dart';
import 'profiles_permissions_hub.dart';

/// Categories for user-defined virtual libraries. These are organizational
/// views over the canonical account catalog; they never copy or move media.
enum VirtualLibraryKind {
  genre,
  director,
  castMember,
  studio,
  language,
  customTag,
}

extension VirtualLibraryKindLabel on VirtualLibraryKind {
  String get label => switch (this) {
        VirtualLibraryKind.genre => 'Genre',
        VirtualLibraryKind.director => 'Director',
        VirtualLibraryKind.castMember => 'Actor / Actress / Cast',
        VirtualLibraryKind.studio => 'Studio / Company',
        VirtualLibraryKind.language => 'Film Language',
        VirtualLibraryKind.customTag => 'Custom Tag / Mood',
      };
}

class VirtualLibraryDefinition {
  VirtualLibraryDefinition({
    required this.id,
    required this.name,
    required this.kind,
    this.description = '',
    this.matchValue = '',
    this.smartMatch = true,
    this.coverArtUrl = '',
    this.backgroundArtUrl = '',
    this.sortTitle = '',
    this.order = 0,
  });

  final String id;
  String name;
  VirtualLibraryKind kind;
  String description;
  String matchValue;
  bool smartMatch;
  String coverArtUrl;
  String backgroundArtUrl;
  String sortTitle;
  int order;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'kind': kind.name,
        'description': description,
        'matchValue': matchValue,
        'smartMatch': smartMatch,
        'coverArtUrl': coverArtUrl,
        'backgroundArtUrl': backgroundArtUrl,
        'sortTitle': sortTitle,
        'order': order,
      };

  factory VirtualLibraryDefinition.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind']?.toString();
    final kind = VirtualLibraryKind.values.firstWhere(
      (value) => value.name == rawKind,
      orElse: () => VirtualLibraryKind.genre,
    );
    return VirtualLibraryDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Library',
      kind: kind,
      description: json['description']?.toString() ?? '',
      matchValue: json['matchValue']?.toString() ?? '',
      smartMatch: json['smartMatch'] != false,
      coverArtUrl: json['coverArtUrl']?.toString() ?? '',
      backgroundArtUrl: json['backgroundArtUrl']?.toString() ?? '',
      sortTitle: json['sortTitle']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class VirtualLibrarySettings {
  VirtualLibrarySettings({
    required this.libraries,
    required this.primaryLibraryByMediaId,
  });

  final List<VirtualLibraryDefinition> libraries;

  /// Exactly one manual primary library per owned media item, where assigned.
  /// Smart metadata libraries are browse lenses and do not create extra catalog
  /// records or alter the item's primary assignment.
  final Map<String, String> primaryLibraryByMediaId;

  factory VirtualLibrarySettings.empty() => VirtualLibrarySettings(
        libraries: <VirtualLibraryDefinition>[],
        primaryLibraryByMediaId: <String, String>{},
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'libraries': libraries.map((item) => item.toJson()).toList(),
        'primaryLibraryByMediaId': primaryLibraryByMediaId,
      };

  factory VirtualLibrarySettings.fromJson(Map<String, dynamic> json) {
    final rawLibraries = json['libraries'] as List? ?? const <dynamic>[];
    final rawPrimary = json['primaryLibraryByMediaId'] as Map? ?? const {};
    return VirtualLibrarySettings(
      libraries: rawLibraries
          .whereType<Map>()
          .map((value) => VirtualLibraryDefinition.fromJson(
                Map<String, dynamic>.from(value),
              ))
          .where((value) => value.id.isNotEmpty && value.name.trim().isNotEmpty)
          .toList(),
      primaryLibraryByMediaId: rawPrimary.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}

/// Profile-scoped virtual-library configuration. A title remains one record
/// in AppController.library regardless of how many smart browse lenses match.
class VirtualLibraryStore {
  VirtualLibraryStore._();
  static final VirtualLibraryStore instance = VirtualLibraryStore._();

  VirtualLibrarySettings settings = VirtualLibrarySettings.empty();

  String get storageKey {
    final controller = AppController.instance;
    final accountId = controller.currentAccount?.id ?? 'local';
    final profileId = controller.currentProfile?.id ?? 'guest';
    return 'virtual_libraries_v1_${accountId}_$profileId';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      settings = VirtualLibrarySettings.empty();
      return;
    }
    try {
      settings = VirtualLibrarySettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      settings = VirtualLibrarySettings.empty();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  Future<void> addLibrary(VirtualLibraryDefinition definition) async {
    if (settings.libraries.any((item) => item.id == definition.id)) return;
    definition.order = settings.libraries.length;
    settings.libraries.add(definition);
    await save();
  }

  Future<void> deleteLibrary(String libraryId) async {
    settings.libraries.removeWhere((item) => item.id == libraryId);
    settings.primaryLibraryByMediaId.removeWhere(
      (_, assignedId) => assignedId == libraryId,
    );
    await save();
  }

  Future<void> reorderLibraries(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= settings.libraries.length) return;
    if (newIndex < 0 || newIndex >= settings.libraries.length) return;
    final item = settings.libraries.removeAt(oldIndex);
    settings.libraries.insert(newIndex, item);
    for (var index = 0; index < settings.libraries.length; index++) {
      settings.libraries[index].order = index;
    }
    await save();
  }

  /// Moves a title's one manual primary membership to [libraryId].
  Future<void> assignPrimary(String mediaId, String libraryId) async {
    settings.primaryLibraryByMediaId[mediaId] = libraryId;
    await save();
  }

  Future<void> clearPrimary(String mediaId,
      {String? onlyWhenAssignedTo}) async {
    if (onlyWhenAssignedTo == null ||
        settings.primaryLibraryByMediaId[mediaId] == onlyWhenAssignedTo) {
      settings.primaryLibraryByMediaId.remove(mediaId);
      await save();
    }
  }
}

String normalizeLibraryValue(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A folder segment should be a simple slug. This validates a suggested
/// layout only; it never renames or moves files on the user's NAS.
bool isSafeLibraryFolderName(String value) => RegExp(
      r'^[a-z0-9]+(?:[_-][a-z0-9]+)*$',
    ).hasMatch(value.trim());

/// Jellyfin-friendly title/year folder form, with an optional TMDb-style id.
bool isStandardMovieFolderName(String value) => RegExp(
      r'^.+\s\((18|19|20)\d{2}\)(?:\s\[(?:tmdbid|imdbid)=?[a-zA-Z0-9_-]+\])?$',
      caseSensitive: false,
    ).hasMatch(value.trim());

/// Metadata-based membership for smart libraries. Smart libraries are virtual
/// browse views; a title still appears once in All Owned Media.
bool virtualLibrarySmartMatches(
  MediaItem media,
  VirtualLibraryDefinition library,
) {
  if (!library.smartMatch) return false;
  final target = normalizeLibraryValue(
      library.matchValue.isNotEmpty ? library.matchValue : library.name);
  if (target.isEmpty) return false;

  Iterable<String> values;
  switch (library.kind) {
    case VirtualLibraryKind.genre:
      // A populated primary genre wins, keeping the main genre library
      // mutually exclusive. Secondary genres remain searchable as tags.
      final primary = media.primaryGenre?.trim() ?? '';
      values = primary.isNotEmpty ? <String>[primary] : media.genres;
      break;
    case VirtualLibraryKind.director:
      values = media.directors;
      break;
    case VirtualLibraryKind.castMember:
      values = media.actors;
      break;
    case VirtualLibraryKind.studio:
      values = <String>[...media.studios, ...media.companies];
      break;
    case VirtualLibraryKind.language:
      values = <String>[
        if (media.originalLanguage?.trim().isNotEmpty == true)
          media.originalLanguage!,
        if (media.language?.trim().isNotEmpty == true) media.language!,
      ];
      break;
    case VirtualLibraryKind.customTag:
      values = <String>[
        ...media.tags,
        ...media.themes,
        ...media.tones,
      ];
      break;
  }
  return values.any((value) => normalizeLibraryValue(value) == target);
}

List<MediaItem> virtualLibraryItems({
  required Iterable<MediaItem> ownedItems,
  required VirtualLibraryDefinition library,
  required VirtualLibrarySettings settings,
}) {
  final result = ownedItems.where((media) {
    if (library.smartMatch && virtualLibrarySmartMatches(media, library)) {
      return true;
    }
    return settings.primaryLibraryByMediaId[media.id] == library.id;
  }).toList();
  result.sort((a, b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  });
  return result;
}

class VirtualLibrariesScreen extends StatefulWidget {
  const VirtualLibrariesScreen({super.key});

  @override
  State<VirtualLibrariesScreen> createState() => _VirtualLibrariesScreenState();
}

class _VirtualLibrariesScreenState extends State<VirtualLibrariesScreen> {
  final store = VirtualLibraryStore.instance;
  final organizationStore = LibraryOrganizationStore.instance;
  bool loading = true;

  static const List<(String, VirtualLibraryKind)> quickStarts =
      <(String, VirtualLibraryKind)>[
    ('Action', VirtualLibraryKind.genre),
    ('Comedy', VirtualLibraryKind.genre),
    ('Drama', VirtualLibraryKind.genre),
    ('Thriller', VirtualLibraryKind.genre),
    ('Sci-Fi', VirtualLibraryKind.genre),
    ('Horror', VirtualLibraryKind.genre),
    ('Animation', VirtualLibraryKind.genre),
    ('Crime & Mystery', VirtualLibraryKind.genre),
    ('Romance', VirtualLibraryKind.genre),
    ('Documentary', VirtualLibraryKind.genre),
    ('Adventure', VirtualLibraryKind.genre),
    ('Date Night', VirtualLibraryKind.customTag),
    ('Rainy Day', VirtualLibraryKind.customTag),
    ('Comfort Movies', VirtualLibraryKind.customTag),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    await organizationStore.load();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _createLibrary({
    String? suggestedName,
    VirtualLibraryKind suggestedKind = VirtualLibraryKind.genre,
  }) async {
    final nameController = TextEditingController(text: suggestedName ?? '');
    final matchController = TextEditingController(text: suggestedName ?? '');
    final descriptionController = TextEditingController();
    final coverController = TextEditingController();
    final backgroundController = TextEditingController();
    var kind = suggestedKind;
    var smart = true;
    final result = await showDialog<VirtualLibraryDefinition>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create virtual library'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Library name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<VirtualLibraryKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: VirtualLibraryKind.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => kind = value);
                  },
                ),
                TextField(
                  controller: matchController,
                  decoration: InputDecoration(
                    labelText: kind == VirtualLibraryKind.customTag
                        ? 'Tag or mood value'
                        : 'Metadata value to match',
                    helperText:
                        'Example: Action, Christopher Nolan, Warner Bros.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: smart,
                  onChanged: (value) =>
                      setDialogState(() => smart = value ?? false),
                  title: const Text('Automatically match metadata'),
                  subtitle: const Text(
                      'Turn off to manually assign each title to this one primary library.'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
                TextField(
                  controller: coverController,
                  decoration: const InputDecoration(
                      labelText: 'Cover artwork HTTPS URL'),
                ),
                TextField(
                  controller: backgroundController,
                  decoration: const InputDecoration(
                      labelText: 'Background artwork HTTPS URL'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final match = matchController.text.trim();
                if (name.isEmpty || (smart && match.isEmpty)) return;
                final now = DateTime.now().microsecondsSinceEpoch;
                Navigator.pop(
                  dialogContext,
                  VirtualLibraryDefinition(
                    id: 'virtual-library-$now',
                    name: name,
                    kind: kind,
                    description: descriptionController.text.trim(),
                    matchValue: match,
                    smartMatch: smart,
                    coverArtUrl: _httpsOrEmpty(coverController.text),
                    backgroundArtUrl: _httpsOrEmpty(backgroundController.text),
                    sortTitle: name,
                  ),
                );
              },
              child: const Text('Create library'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    matchController.dispose();
    descriptionController.dispose();
    coverController.dispose();
    backgroundController.dispose();
    if (result == null) return;
    await store.addLibrary(result);
    if (mounted) setState(() {});
  }

  String _httpsOrEmpty(String raw) {
    final value = raw.trim();
    return value.startsWith('https://') ? value : '';
  }

  void _openNamingGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Library structure & naming guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Suggested structure'),
              SizedBox(height: 6),
              SelectableText('Media/Movies/Action/Movie Name (2024)/'),
              SelectableText('Media/Movies/Comedy/Movie Name (2021)/'),
              SelectableText('Media/TV Shows/Drama/Show Name (2020)/'),
              SelectableText('Media/Music/Albums/Artist/Album/'),
              SizedBox(height: 12),
              Text(
                  'Use a single, clear primary category for each movie or show. Use tags for cross-cutting ideas such as date night, rainy day, comfort movies, favorite actor, language, or director. Use collections for franchises and connected titles.'),
              SizedBox(height: 12),
              Text('Movie folder naming'),
              SizedBox(height: 6),
              SelectableText('Movie Name (Year) [tmdbid=12345]'),
              SizedBox(height: 8),
              Text(
                  'Use simple folder names with lowercase letters, numbers, underscores or hyphens. Keep the title and year in the media folder name. Aim for at least 8 titles in a library; 16 or more makes a fuller browse shelf. Split a large category only when the subcategories are easy to understand.'),
              SizedBox(height: 12),
              Text(
                  'This guide does not rename or move NAS files. FileBot or TinyMediaManager are external tools; review their proposed changes and keep a backup before applying them.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final owned = AllOwnedMediaCatalog.visibleOwnedItems(controller);
    final libraries = [...store.settings.libraries]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Libraries'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Folder structure & naming guide',
            onPressed: _openNamingGuide,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            tooltip: 'Create library',
            onPressed: _createLibrary,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'A curated home for every kind of entertainment',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${owned.length} owned titles are available to this profile. Give movies, shows and albums a clear primary home, then use tags and collections to connect related items.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'One canonical copy stays in the shared catalog. Smart libraries are metadata-driven views; manual libraries allow one primary assignment per title.',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: <Widget>[
                              for (final template in quickStarts)
                                ActionChip(
                                  label: Text('+ ${template.$1}'),
                                  onPressed: () => _createLibrary(
                                    suggestedName: template.$1,
                                    suggestedKind: template.$2,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Your libraries (${libraries.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openNamingGuide,
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('Naming tips'),
                      ),
                    ],
                  ),
                  if (libraries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                            'Create your first library above. Start with a few obvious categories such as Action, Comedy, Drama, or Family rather than making too many small libraries.'),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: libraries.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        await store.reorderLibraries(oldIndex, newIndex);
                        if (mounted) setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final library = libraries[index];
                        final items = virtualLibraryItems(
                          ownedItems: owned,
                          library: library,
                          settings: store.settings,
                        );
                        final count = items.length;
                        final guidance = count < 8
                            ? 'Small shelf · ${8 - count} more suggested'
                            : count < 16
                                ? 'Good start · 16+ makes a fuller shelf'
                                : 'Well stocked';
                        return Card(
                          key: ValueKey(library.id),
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => VirtualLibraryDetailScreen(
                                    libraryId: library.id),
                              ),
                            ),
                            child: SizedBox(
                              height: 112,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (library.backgroundArtUrl.isNotEmpty)
                                    Image.network(
                                      library.backgroundArtUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          Colors.black.withValues(alpha: .94),
                                          Colors.black.withValues(alpha: .60),
                                          Colors.black.withValues(alpha: .82),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: <Widget>[
                                        if (library.coverArtUrl.isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            child: Image.network(
                                              library.coverArtUrl,
                                              width: 58,
                                              height: 82,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons
                                                          .video_library_rounded,
                                                      size: 42),
                                            ),
                                          )
                                        else
                                          const SizedBox(
                                            width: 58,
                                            child: Icon(
                                                Icons.video_library_rounded,
                                                size: 38),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(library.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                              const SizedBox(height: 3),
                                              Text(
                                                  '${library.kind.label} · $count titles',
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12)),
                                              const SizedBox(height: 3),
                                              Text(guidance,
                                                  style: TextStyle(
                                                      color: count < 8
                                                          ? Colors
                                                              .amber.shade200
                                                          : Colors.white60,
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.drag_handle_rounded,
                                            color: Colors.white54),
                                        const Icon(Icons.chevron_right_rounded),
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
                  const SizedBox(height: 10),
                  const Text(
                    'Use Collections for franchises and multi-title relationships. Use tags for actor, director, language, mood and other cross-cutting labels. A title can have many tags and belong to several collections while retaining one primary manual library.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.family_restroom_rounded),
                      title: const Text('Kids and guest profile access'),
                      subtitle: const Text(
                          'Open the existing profile permission center to control which shared media each profile can access. Presentation settings in this screen are not a security boundary.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const ProfilesAndPermissionsHubScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class VirtualLibraryDetailScreen extends StatefulWidget {
  const VirtualLibraryDetailScreen({super.key, required this.libraryId});
  final String libraryId;

  @override
  State<VirtualLibraryDetailScreen> createState() =>
      _VirtualLibraryDetailScreenState();
}

class _VirtualLibraryDetailScreenState
    extends State<VirtualLibraryDetailScreen> {
  final store = VirtualLibraryStore.instance;
  final organizationStore = LibraryOrganizationStore.instance;
  bool loading = true;
  String query = '';
  final queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    await organizationStore.load();
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _manageTitles(
      VirtualLibraryDefinition library, List<MediaItem> owned) async {
    if (library.smartMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This library is metadata-matched. Update a title’s metadata or turn off smart matching to assign titles manually.')),
      );
      return;
    }
    final searchController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filtered = owned
              .where((media) => media.title
                  .toLowerCase()
                  .contains(searchController.text.trim().toLowerCase()))
              .toList();
          return AlertDialog(
            title: Text('Assign titles · ${library.name}'),
            content: SizedBox(
              width: 520,
              height: 480,
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search owned media'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final media = filtered[index];
                        final selected =
                            store.settings.primaryLibraryByMediaId[media.id] ==
                                library.id;
                        final assignedElsewhere =
                            store.settings.primaryLibraryByMediaId[media.id];
                        return CheckboxListTile(
                          value: selected,
                          title: Text(media.title),
                          subtitle: Text(assignedElsewhere != null &&
                                  assignedElsewhere != library.id
                              ? 'Currently assigned to ${_libraryName(assignedElsewhere) ?? 'another library'}'
                              : media.type),
                          onChanged: (checked) async {
                            if (checked == true) {
                              await store.assignPrimary(media.id, library.id);
                            } else {
                              await store.clearPrimary(media.id,
                                  onlyWhenAssignedTo: library.id);
                            }
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done')),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _addTag(MediaItem media) async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add a tag · ${media.title}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Tag, actor, director, language or mood'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Add tag')),
        ],
      ),
    );
    controller.dispose();
    if (tag == null || tag.trim().isEmpty) return;
    final tags = organizationStore.settings.tagsByMediaId
        .putIfAbsent(media.id, () => <String>[]);
    if (!tags.any((value) =>
        normalizeLibraryValue(value) == normalizeLibraryValue(tag))) {
      tags.add(tag);
      await organizationStore.save();
    }
    if (mounted) setState(() {});
  }

  String? _libraryName(String id) {
    for (final item in store.settings.libraries) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final matchingLibraries =
        store.settings.libraries.where((item) => item.id == widget.libraryId);
    final VirtualLibraryDefinition? library =
        matchingLibraries.isEmpty ? null : matchingLibraries.first;
    final owned =
        AllOwnedMediaCatalog.visibleOwnedItems(AppController.instance);
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (library == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Library')),
        body:
            const Center(child: Text('This virtual library no longer exists.')),
      );
    }
    final allItems = virtualLibraryItems(
      ownedItems: owned,
      library: library,
      settings: store.settings,
    );
    final visible = allItems
        .where((media) =>
            media.title.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(library.name),
        actions: <Widget>[
          if (!library.smartMatch)
            IconButton(
              tooltip: 'Assign titles',
              onPressed: () => _manageTitles(library, owned),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                await store.deleteLibrary(library.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(
                  value: 'delete', child: Text('Delete virtual library')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                if (library.backgroundArtUrl.isNotEmpty)
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Image.network(library.backgroundArtUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(library.description.isEmpty
                          ? '${library.kind.label} library'
                          : library.description),
                      const SizedBox(height: 6),
                      Text(
                          '${visible.length} titles · ${library.smartMatch ? 'Smart metadata view' : 'Manual primary library'}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: queryController,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Find in this library'),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(library.smartMatch
                              ? 'No owned titles match “${library.matchValue}” yet.'
                              : 'No titles assigned yet. Use the add button to choose owned titles.'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final media = visible[index];
                            final tags = organizationStore
                                    .settings.tagsByMediaId[media.id] ??
                                const <String>[];
                            return ListTile(
                              leading: media.imageUrl?.isNotEmpty == true
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: Image.network(media.imageUrl!,
                                          width: 48,
                                          height: 68,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.movie_outlined)),
                                    )
                                  : const Icon(Icons.movie_outlined),
                              title: Text(media.title),
                              subtitle: Text(
                                  <String>[
                                    media.type,
                                    if (tags.isNotEmpty) tags.join(' · ')
                                  ].join('  •  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'tag') _addTag(media);
                                  if (value == 'details') {
                                    Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) => MediaDetailsScreen(
                                                media: media)));
                                  }
                                },
                                itemBuilder: (_) =>
                                    const <PopupMenuEntry<String>>[
                                  PopupMenuItem(
                                      value: 'details',
                                      child: Text('Open details')),
                                  PopupMenuItem(
                                      value: 'tag', child: Text('Add tag')),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          MediaDetailsScreen(media: media))),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
