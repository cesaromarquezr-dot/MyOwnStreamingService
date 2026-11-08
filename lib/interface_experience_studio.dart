import 'package:flutter/material.dart';

import 'app_core.dart';
import 'interface_experience.dart';
import 'virtual_store_experience_screen.dart';
import 'screens/redbox_home_screen.dart';
import 'screens/theater_home_screen.dart';

class _ExperienceDesignOption {
  const _ExperienceDesignOption({required this.id, required this.name});

  final String id;
  final String name;
}

class InterfaceExperienceStudioScreen extends StatefulWidget {
  const InterfaceExperienceStudioScreen({super.key});

  @override
  State<InterfaceExperienceStudioScreen> createState() =>
      _InterfaceExperienceStudioScreenState();
}

class _InterfaceExperienceStudioScreenState
    extends State<InterfaceExperienceStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  InterfaceExperienceConfig? _config;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await InterfaceExperienceRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
    _tabs.animateTo(
        switch (parseInterfaceExperienceMode(config.activeExperience)) {
      InterfaceExperienceMode.classic => 0,
      InterfaceExperienceMode.blockbuster => 1,
      InterfaceExperienceMode.redbox => 2,
      InterfaceExperienceMode.theater => 4,
    });
  }

  Future<void> _save(String label) async {
    final config = _config;
    if (config == null) return;
    setState(() => _saving = true);
    try {
      config.activeStore?.checkpoint(label);
      config.activeKiosk?.checkpoint(label);
      await InterfaceExperienceRepository.instance.save(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$label saved for ${AppController.instance.currentProfile?.name ?? 'this profile'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InterfaceExperienceConfig get config => _config!;

  Future<String?> _textDialog({
    required String title,
    String initial = '',
    String hint = '',
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _addAisle() async {
    final name = await _textDialog(
        title: 'Name your aisle', hint: 'e.g. Marvel Cinematic Universe');
    if (!mounted || name == null || name.isEmpty) return;
    final description = await _textDialog(
            title: 'Aisle description', hint: 'What belongs here?') ??
        '';
    if (!mounted) return;
    final filter = await _filterDialog();
    if (!mounted) return;
    setState(() {
      config.activeStore?.aisles.add(StoreAisle(
        name: name,
        description: description,
        filterType: filter?['type'] ?? 'manual',
        filterValue: filter?['value'] ?? '',
      ));
    });
    await _save('Aisle');
  }

  Future<Map<String, String>?> _filterDialog({
    String initialType = 'manual',
    String initialValue = '',
  }) async {
    String type = initialType;
    final value = TextEditingController(text: initialValue);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dynamic shelf rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Fill from'),
                items: const [
                  DropdownMenuItem(
                      value: 'manual', child: Text('Manually selected titles')),
                  DropdownMenuItem(value: 'genre', child: Text('Genre')),
                  DropdownMenuItem(
                      value: 'country', child: Text('Production country')),
                  DropdownMenuItem(value: 'decade', child: Text('Decade')),
                  DropdownMenuItem(
                      value: 'franchise', child: Text('Franchise / universe')),
                  DropdownMenuItem(value: 'studio', child: Text('Studio')),
                  DropdownMenuItem(value: 'type', child: Text('Media type')),
                  DropdownMenuItem(value: 'tag', child: Text('Tag')),
                  DropdownMenuItem(
                      value: 'recent', child: Text('Recently added')),
                  DropdownMenuItem(
                      value: 'favorites', child: Text('Favorites')),
                  DropdownMenuItem(
                      value: 'all', child: Text('Entire eligible library')),
                ],
                onChanged: (next) =>
                    setDialogState(() => type = next ?? 'manual'),
              ),
              const SizedBox(height: 12),
              if (!{'manual', 'recent', 'favorites', 'all'}.contains(type))
                TextField(
                  controller: value,
                  decoration: InputDecoration(
                    labelText: type == 'country'
                        ? 'Country (e.g. Mexico, US, Canada, Spain)'
                        : type == 'decade'
                            ? 'Decade (e.g. 1990)'
                            : type == 'type'
                                ? 'Media type: movie, tv or music'
                                : 'Match value',
                  ),
                ),
              if (type == 'manual')
                const Text(
                    'Choose exact titles from the collection picker after creating the shelf.'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    dialogContext, {'type': type, 'value': value.text.trim()}),
                child: const Text('Use rule')),
          ],
        ),
      ),
    );
    value.dispose();
    return result;
  }

  Future<void> _editAisle(StoreAisle aisle) async {
    final name =
        await _textDialog(title: 'Edit aisle name', initial: aisle.name);
    if (!mounted || name == null || name.isEmpty) return;
    final description = await _textDialog(
        title: 'Aisle description', initial: aisle.description, maxLines: 3);
    if (!mounted) return;
    setState(() {
      aisle.name = name;
      if (description != null) aisle.description = description;
    });
    await _save('Aisle settings');
  }

  Future<void> _addShelf(StoreAisle aisle) async {
    final title = await _textDialog(title: 'Shelf name', hint: 'e.g. Phase 1');
    if (!mounted || title == null || title.isEmpty) return;
    final filter = await _filterDialog();
    if (!mounted) return;
    setState(() => aisle.shelves.add(ExperienceContentRule(
          title: title,
          filterType: filter?['type'] ?? aisle.filterType,
          filterValue: filter?['value'] ?? aisle.filterValue,
        )));
    await _save('Shelf');
  }

  Future<void> _addKioskCategory() async {
    final title = await _textDialog(
        title: 'Kiosk category name', hint: 'e.g. Mexican Cinema');
    if (!mounted || title == null || title.isEmpty) return;
    final description = await _textDialog(title: 'Category description') ?? '';
    if (!mounted) return;
    final filter = await _filterDialog();
    if (!mounted) return;
    setState(() => config.activeKiosk?.categories.add(KioskCategoryDesign(
          title: title,
          description: description,
          filterType: filter?['type'] ?? 'manual',
          filterValue: filter?['value'] ?? '',
        )));
    await _save('Kiosk category');
  }

  Future<void> _addStore() async {
    final name = await _textDialog(
        title: 'Create a virtual store', hint: "e.g. Cesar's Horror Emporium");
    if (!mounted || name == null || name.isEmpty) return;
    final store = VirtualStoreDesign(
      name: name,
      aisles: [
        StoreAisle(
          name: 'All Owned Media',
          description: 'Everything available to the active profile',
          filterType: 'all',
          color: 0xFF8B7CFF,
        ),
        StoreAisle(
          name: 'Movies',
          description: 'Your owned movie collection',
          filterType: 'type',
          filterValue: 'movie',
          color: 0xFFB71C1C,
        ),
        StoreAisle(
          name: 'TV Shows & Specials',
          description: 'Your series, episodes and TV specials',
          filterType: 'type',
          filterValue: 'tv',
          color: 0xFF1565C0,
        ),
        StoreAisle(
          name: 'Music Collection',
          description: 'Your owned albums and songs',
          filterType: 'type',
          filterValue: 'music',
          color: 0xFF00897B,
        ),
      ],
    );
    setState(() {
      config.stores.add(store);
      config.activeStoreId = store.id;
      config.baseStoreId = store.id;
    });
    await _save('Virtual store');
  }

  Future<void> _addKiosk() async {
    final name = await _textDialog(
        title: 'Create a kiosk design', hint: 'e.g. Family Movie Kiosk');
    if (!mounted || name == null || name.isEmpty) return;
    final kiosk = KioskDesign(
      name: name,
      categories: [
        KioskCategoryDesign(
          title: 'All Owned Media',
          description: 'Everything available to this profile',
          filterType: 'all',
          featured: true,
        ),
        KioskCategoryDesign(
          title: 'Movies',
          description: 'Your owned movies',
          filterType: 'type',
          filterValue: 'movie',
        ),
        KioskCategoryDesign(
          title: 'TV Shows & Specials',
          description: 'Your owned series and standalone specials',
          filterType: 'type',
          filterValue: 'tv',
        ),
        KioskCategoryDesign(
          title: 'Music & Albums',
          description: 'Your owned music collection',
          filterType: 'type',
          filterValue: 'music',
        ),
      ],
    );
    setState(() {
      config.kiosks.add(kiosk);
      config.activeKioskId = kiosk.id;
      config.baseKioskId = kiosk.id;
    });
    await _save('Kiosk design');
  }

  Future<void> _editStoreBranding(VirtualStoreDesign store) async {
    final name = await _textDialog(title: 'Store name', initial: store.name);
    if (!mounted || name == null || name.isEmpty) return;
    final greeting = await _textDialog(
        title: 'Welcome message', initial: store.greeting, maxLines: 2);
    if (!mounted) return;
    final logo = await _textDialog(
        title: 'Logo image URL (optional)', initial: store.logoUrl);
    if (!mounted) return;
    setState(() {
      store.name = name;
      if (greeting != null) store.greeting = greeting;
      if (logo != null) store.logoUrl = logo;
    });
    await _save('Store branding');
  }

  Future<void> _editKioskBranding(KioskDesign kiosk) async {
    final name = await _textDialog(title: 'Kiosk name', initial: kiosk.name);
    if (!mounted || name == null || name.isEmpty) return;
    final greeting = await _textDialog(
        title: 'Welcome greeting', initial: kiosk.greeting, maxLines: 2);
    if (!mounted) return;
    final logo = await _textDialog(
        title: 'Logo image URL (optional)', initial: kiosk.logoUrl);
    if (!mounted) return;
    setState(() {
      kiosk.name = name;
      if (greeting != null) kiosk.greeting = greeting;
      if (logo != null) kiosk.logoUrl = logo;
    });
    await _save('Kiosk branding');
  }

  Future<void> _saveTemplate(String kind) async {
    final name =
        await _textDialog(title: 'Save $kind template', hint: 'Template name');
    if (!mounted || name == null || name.isEmpty) return;
    final store = config.activeStore;
    final kiosk = config.activeKiosk;
    final template = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'kind': kind,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      if (kind == 'store' && store != null)
        'design': store.toJson(includeRevisions: false),
      if (kind == 'kiosk' && kiosk != null)
        'design': kiosk.toJson(includeRevisions: false),
    };
    setState(() => config.savedTemplates.add(template));
    await _save('Template');
  }

  Future<void> _restoreRevision({required bool store}) async {
    final design = store ? config.activeStore : config.activeKiosk;
    final revisions = store
        ? (design as VirtualStoreDesign?)?.revisions ?? <Map<String, dynamic>>[]
        : (design as KioskDesign?)?.revisions ?? <Map<String, dynamic>>[];
    if (design == null || revisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved versions yet.')));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Design version history'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: revisions.reversed
                .map((revision) => ListTile(
                      title: Text(
                          revision['label']?.toString() ?? 'Saved version'),
                      subtitle: Text(revision['createdAt']?.toString() ?? ''),
                      trailing: const Icon(Icons.restore_rounded),
                      onTap: () => Navigator.pop(dialogContext, revision),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'))
        ],
      ),
    );
    if (!mounted) return;
    final snapshot = selected?['snapshot'];
    if (snapshot is! Map) return;
    setState(() {
      if (store) {
        final index =
            config.stores.indexWhere((item) => item.id == config.activeStoreId);
        if (index >= 0) {
          final restored =
              VirtualStoreDesign.fromJson(Map<String, dynamic>.from(snapshot));
          restored.revisions =
              List<Map<String, dynamic>>.from(config.stores[index].revisions);
          config.stores[index] = restored;
        }
      } else {
        final index =
            config.kiosks.indexWhere((item) => item.id == config.activeKioskId);
        if (index >= 0) {
          final restored =
              KioskDesign.fromJson(Map<String, dynamic>.from(snapshot));
          restored.revisions =
              List<Map<String, dynamic>>.from(config.kiosks[index].revisions);
          config.kiosks[index] = restored;
        }
      }
    });
    await _save('Restored design');
  }

  Future<void> _addSeasonalSchedule({required bool store}) async {
    final List<_ExperienceDesignOption> designOptions;
    if (store) {
      designOptions = config.stores
          .map((VirtualStoreDesign design) => _ExperienceDesignOption(
                id: design.id,
                name: design.name,
              ))
          .toList(growable: false);
    } else {
      designOptions = config.kiosks
          .map((KioskDesign design) => _ExperienceDesignOption(
                id: design.id,
                name: design.name,
              ))
          .toList(growable: false);
    }
    if (designOptions.isEmpty) return;

    final nameController = TextEditingController(text: 'Seasonal design');
    final startController = TextEditingController(text: '10-01');
    final endController = TextEditingController(text: '10-31');
    final activeId = store ? config.activeStoreId : config.activeKioskId;
    final hasActiveDesign = activeId != null &&
        designOptions
            .any((_ExperienceDesignOption design) => design.id == activeId);
    String selectedId = hasActiveDesign ? activeId : designOptions.first.id;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(store
              ? 'Schedule a seasonal store'
              : 'Schedule a seasonal kiosk'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Schedule name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: store
                      ? 'Store design to activate'
                      : 'Kiosk design to activate',
                ),
                items: designOptions
                    .map(
                      (_ExperienceDesignOption design) =>
                          DropdownMenuItem<String>(
                        value: design.id,
                        child: Text(design.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setDialogState(
                  () => selectedId = value ?? selectedId,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Start date (MM-DD)',
                  hintText: '10-01',
                ),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'End date (MM-DD)',
                  hintText: '10-31',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use month-day format. The schedule is checked when the profile loads; ranges can cross New Year.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': nameController.text.trim(),
                'designId': selectedId,
                'start': startController.text.trim(),
                'end': endController.text.trim(),
              }),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    startController.dispose();
    endController.dispose();

    if (result == null || !mounted) return;
    final start = result['start']?.trim() ?? '';
    final end = result['end']?.trim() ?? '';
    if (start.isEmpty || end.isEmpty) return;

    final selectedDesignId = result['designId'];
    final schedule = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': (result['name']?.trim().isNotEmpty ?? false)
          ? result['name']!.trim()
          : 'Seasonal design',
      'start': start,
      'end': end,
      'designId': selectedDesignId,
      'kind': store ? 'store' : 'kiosk',
    };

    setState(() {
      config.seasonalAutomationEnabled = true;
      config.seasonalSchedules.add(schedule);
      if (store) {
        for (final VirtualStoreDesign design in config.stores) {
          if (design.id == selectedDesignId) {
            design.seasonalRules.add(schedule);
            break;
          }
        }
      } else {
        for (final KioskDesign design in config.kiosks) {
          if (design.id == selectedDesignId) {
            design.seasonalRules.add(schedule);
            break;
          }
        }
      }
    });
    await _save('Seasonal schedule');
  }

  Future<void> _addDecoration({required bool store}) async {
    final label = await _textDialog(
      title: store ? 'Name the in-store display' : 'Name the kiosk decoration',
      hint: store
          ? 'e.g. New releases, Marvel wall poster, Music aisle'
          : 'e.g. Featured display',
    );
    if (!mounted || label == null || label.isEmpty) return;

    String type = 'decoration';
    String placement = 'Front entrance';
    if (store) {
      final chosenType = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('What are you adding?'),
          children: [
            for (final option in const <(String, String)>[
              ('poster', 'Framed wall poster'),
              ('hangingBanner', 'Hanging aisle banner'),
              ('standee', 'Life-size poster standee'),
              ('neonSign', 'Neon wall sign'),
              ('decoration', 'Store decoration'),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option.$1),
                child: Text(option.$2),
              ),
          ],
        ),
      );
      if (!mounted || chosenType == null) return;
      type = chosenType;
      final chosenPlacement = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Where should it be placed?'),
          children: [
            for (final option in const [
              'Front entrance',
              'Left wall',
              'Right wall',
              'Back wall',
              'Overhead aisle',
              'Center island',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option),
                child: Text(option),
              ),
          ],
        ),
      );
      if (!mounted || chosenPlacement == null) return;
      placement = chosenPlacement;
    }
    String? posterMediaId;
    if (store && (type == 'poster' || type == 'standee')) {
      final selection = <String>[];
      await _pickMedia(
        destination: selection,
        title: 'Select owned-media artwork for this display',
      );
      if (!mounted) return;
      if (selection.isNotEmpty) posterMediaId = selection.first;
    }
    final positions = <String, (double, double)>{
      'Front entrance': (.5, .15),
      'Left wall': (.15, .5),
      'Right wall': (.85, .5),
      'Back wall': (.5, .85),
      'Overhead aisle': (.5, .35),
      'Center island': (.5, .65),
    };
    final position = positions[placement] ?? (.5, .5);
    final item = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': type,
      'label': label,
      'placement': placement,
      if (posterMediaId != null) 'mediaId': posterMediaId,
      'x': position.$1,
      'y': position.$2,
      'width': type == 'hangingBanner' ? 0.28 : 0.18,
      'height': type == 'hangingBanner' ? 0.10 : 0.16,
    };
    setState(() {
      if (store) {
        config.activeStore?.layoutElements.add(item);
      } else {
        config.activeKiosk?.decorations.add(item);
      }
    });
    await _save(store ? 'Store display' : 'Kiosk decoration');
  }

  Future<void> _addStoreCuratedCollection(VirtualStoreDesign store) async {
    final title = await _textDialog(
      title: 'New digital collection',
      hint: 'e.g. Family Movie Night',
    );
    if (!mounted || title == null || title.isEmpty) return;
    final description = await _textDialog(
          title: 'Collection description',
          hint:
              'A group of titles you curated; this is not a physical box set.',
          maxLines: 2,
        ) ??
        '';
    if (!mounted) return;
    final mediaIds = <String>[];
    await _pickMedia(
      destination: mediaIds,
      title: 'Choose titles for $title',
    );
    if (!mounted || mediaIds.isEmpty) return;
    final selectedMedia = AppController.instance.library
        .where((item) => mediaIds.contains(item.id));
    var artworkUrl = '';
    for (final item in selectedMedia) {
      if (item.imageUrl?.trim().isNotEmpty == true) {
        artworkUrl = item.imageUrl!;
        break;
      }
    }
    setState(() {
      store.curatedCollections.add(StoreCuratedCollection(
        title: title,
        description: description,
        mediaIds: mediaIds,
        artworkUrl: artworkUrl,
      ));
    });
    await _save('Digital collection');
  }

  Future<void> _editStoreCuratedCollection(
    VirtualStoreDesign store,
    StoreCuratedCollection collection,
  ) async {
    await _pickMedia(
      destination: collection.mediaIds,
      title: 'Choose titles for ${collection.title}',
    );
    if (!mounted) return;
    final selectedMedia = AppController.instance.library
        .where((item) => collection.mediaIds.contains(item.id));
    if (selectedMedia.isNotEmpty && collection.artworkUrl.isEmpty) {
      collection.artworkUrl = selectedMedia.first.imageUrl ?? '';
    }
    setState(() {});
    await _save('Digital collection contents');
  }

  Future<void> _pickMedia(
      {required List<String> destination, required String title}) async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final library = controller.library
        .where((item) =>
            item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList();
    if (library.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your library is empty. Import media first.')));
      return;
    }
    final chosen = <String>{...destination};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            height: 420,
            child: ListView.builder(
              itemCount: library.length,
              itemBuilder: (context, index) {
                final item = library[index];
                return CheckboxListTile(
                  value: chosen.contains(item.id),
                  title: Text(item.title),
                  subtitle: Text(
                      '${item.type} · ${item.releaseYear ?? 'Year unknown'}'),
                  secondary: item.imageUrl == null
                      ? const Icon(Icons.movie_outlined)
                      : Image.network(item.imageUrl!,
                          width: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.movie_outlined)),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      chosen.add(item.id);
                    } else {
                      chosen.remove(item.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, chosen.toList()),
                child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      destination
        ..clear()
        ..addAll(result);
    });
    await _save('Collection selection');
  }

  List<MediaItem> _titlesForRule({
    required String filterType,
    String filterValue = '',
    List<String> manualIds = const [],
  }) {
    final library = AppController.instance.library
        .where((item) => AppController.instance.isOwned(item.id))
        .toList();
    final target = filterValue.trim().toLowerCase();
    Iterable<MediaItem> items = library;
    switch (filterType) {
      case 'manual':
        items = library.where((item) => manualIds.contains(item.id));
        break;
      case 'genre':
        items = library.where((item) =>
            item.genres.any((genre) => genre.toLowerCase() == target) ||
            item.primaryGenre?.toLowerCase() == target);
        break;
      case 'country':
        items = library
            .where((item) => item.countryOfOrigin?.toLowerCase() == target);
        break;
      case 'decade':
        final decade = int.tryParse(filterValue.trim());
        if (decade != null) {
          items = library.where((item) =>
              item.releaseYear != null &&
              item.releaseYear! >= decade &&
              item.releaseYear! < decade + 10);
        }
        break;
      case 'franchise':
        items = library.where((item) =>
            item.franchiseNames
                .any((name) => name.toLowerCase().contains(target)) ||
            item.franchiseName?.toLowerCase().contains(target) == true ||
            item.cinematicUniverseNames
                .any((name) => name.toLowerCase().contains(target)));
        break;
      case 'studio':
        items = library.where((item) =>
            item.studios
                .any((studio) => studio.toLowerCase().contains(target)) ||
            item.companies
                .any((company) => company.toLowerCase().contains(target)));
        break;
      case 'type':
        if (target == 'music' || target == 'audio') {
          items = library.where((item) {
            final mediaType = item.type.toLowerCase().replaceAll('_', ' ');
            return mediaType.contains('music') ||
                mediaType.contains('song') ||
                mediaType.contains('track') ||
                mediaType.contains('album') ||
                mediaType.contains('audio');
          });
        } else if (target == 'tv' ||
            target == 'television' ||
            target == 'specials') {
          items = library.where((item) {
            final mediaType = item.type.toLowerCase().replaceAll('_', ' ');
            return mediaType.contains('tv') ||
                mediaType.contains('show') ||
                mediaType.contains('series') ||
                mediaType.contains('episode') ||
                mediaType.contains('special');
          });
        } else if (target == 'movie' ||
            target == 'movies' ||
            target == 'film') {
          items = library.where((item) {
            final mediaType = item.type.toLowerCase();
            return mediaType.contains('movie') || mediaType.contains('film');
          });
        } else {
          items = library.where(
              (item) => item.type.toLowerCase().replaceAll('_', ' ') == target);
        }
        break;
      case 'tag':
        items = library.where(
            (item) => item.tags.any((tag) => tag.toLowerCase() == target));
        break;
      case 'recent':
        final sorted = library.toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return sorted.take(30).toList();
      case 'favorites':
        items = library.where((item) =>
            AppController.instance.liked.any((liked) => liked.id == item.id));
        break;
      case 'all':
        break;
    }
    return items.take(80).toList();
  }

  Future<void> _addCaseDesign() async {
    final name = await _textDialog(
        title: 'Case design name', hint: 'e.g. Custom 4K Collector Edition');
    if (!mounted || name == null || name.isEmpty) return;
    final type = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose case format'),
        children: ['VHS', 'DVD', 'Blu-ray', '4K Ultra HD', 'Custom']
            .map((value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, value),
                child: Text(value)))
            .toList(),
      ),
    );
    if (!mounted || type == null) return;
    final caseId = _experienceIdForUi();
    setState(() {
      config.activeCaseDesignId = caseId;
      config.caseDesigns.add({
        'id': caseId,
        'name': name,
        'format': type,
        'frontTitle': 'Movie Title',
        'spineText': name,
        'backText': 'Synopsis, cast and credits',
        'discLabel': 'Disc 1',
        'frontArtUrl': '',
        'spineArtUrl': '',
        'backArtUrl': '',
        'discArtUrl': '',
        'primaryColor': 0xFF123D74,
        'secondaryColor': 0xFF101820,
      });
    });
    await _save('Case design');
  }

  String _experienceIdForUi() =>
      'case_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _editCaseDesign(Map<String, dynamic> design) async {
    final front = await _textDialog(
        title: 'Front cover title',
        initial: design['frontTitle']?.toString() ?? '');
    if (!mounted) return;
    final spine = await _textDialog(
        title: 'Spine text', initial: design['spineText']?.toString() ?? '');
    if (!mounted) return;
    final back = await _textDialog(
        title: 'Back cover text',
        initial: design['backText']?.toString() ?? '',
        maxLines: 4);
    if (!mounted) return;
    final disc = await _textDialog(
        title: 'Disc label', initial: design['discLabel']?.toString() ?? '');
    if (!mounted) return;
    final frontArt = await _textDialog(
        title: 'Front artwork URL (optional)',
        initial: design['frontArtUrl']?.toString() ?? '');
    if (!mounted) return;
    final spineArt = await _textDialog(
        title: 'Spine artwork URL (optional)',
        initial: design['spineArtUrl']?.toString() ?? '');
    if (!mounted) return;
    final backArt = await _textDialog(
        title: 'Back artwork URL (optional)',
        initial: design['backArtUrl']?.toString() ?? '');
    if (!mounted) return;
    final discArt = await _textDialog(
        title: 'Disc label artwork URL (optional)',
        initial: design['discArtUrl']?.toString() ?? '');
    if (!mounted) return;
    setState(() {
      if (front != null) design['frontTitle'] = front;
      if (spine != null) design['spineText'] = spine;
      if (back != null) design['backText'] = back;
      if (disc != null) design['discLabel'] = disc;
      if (frontArt != null) design['frontArtUrl'] = frontArt;
      if (spineArt != null) design['spineArtUrl'] = spineArt;
      if (backArt != null) design['backArtUrl'] = backArt;
      if (discArt != null) design['discArtUrl'] = discArt;
    });
    await _save('Case artwork');
  }

  Future<void> _launchExperience(InterfaceExperienceMode mode) async {
    setState(() => config.activeExperience = mode.name);
    await _save('Interface selection');
    if (!mounted) return;
    Navigator.of(context).popUntil((route) {
      final name = route.settings.name ?? '';
      return name.startsWith('/main/') || route.isFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activeStore = config.activeStore;
    final activeKiosk = config.activeKiosk;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interface Experience Studio'),
        actions: [
          if (_saving)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))))
          else
            IconButton(
                tooltip: 'Save all designs',
                onPressed: () => _save('Designs'),
                icon: const Icon(Icons.save_rounded)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(
                icon: Icon(Icons.switch_access_shortcut_rounded),
                text: 'Experiences'),
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Virtual Store'),
            Tab(icon: Icon(Icons.dns_rounded), text: 'Redbox Kiosk'),
            Tab(
                icon: Icon(Icons.collections_bookmark_rounded),
                text: 'Collections & Cases'),
            Tab(
                icon: Icon(Icons.movie_filter_rounded),
                text: 'Owned Library & Theater'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildExperienceTab(),
          _buildStoreTab(activeStore),
          _buildKioskTab(activeKiosk),
          _buildCollectionsTab(),
          _buildOwnershipAndTheaterTab(),
        ],
      ),
    );
  }

  Widget _buildExperienceTab() {
    final selected = parseInterfaceExperienceMode(config.activeExperience);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Choose Your Experience',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
            'Each interface has its own saved design. Your media library, profiles and playback remain shared.'),
        const SizedBox(height: 14),
        for (final mode in InterfaceExperienceMode.values)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                  child: Icon(switch (mode) {
                InterfaceExperienceMode.classic => Icons.home_rounded,
                InterfaceExperienceMode.blockbuster => Icons.storefront_rounded,
                InterfaceExperienceMode.redbox => Icons.dns_rounded,
                InterfaceExperienceMode.theater => Icons.theaters_rounded,
              })),
              title: Text(mode.label,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(mode.description),
              trailing: selected == mode
                  ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                setState(() => config.activeExperience = mode.name);
                _tabs.animateTo(switch (mode) {
                  InterfaceExperienceMode.classic => 0,
                  InterfaceExperienceMode.blockbuster => 1,
                  InterfaceExperienceMode.redbox => 2,
                  InterfaceExperienceMode.theater => 4,
                });
                await _save('Interface preference');
              },
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _launchExperience(selected),
          icon: const Icon(Icons.launch_rounded),
          label: Text(selected == InterfaceExperienceMode.classic
              ? 'Return to Classic Home'
              : 'Launch ${selected.label}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ExperiencePreviewScreen(
                  mode: InterfaceExperienceMode.blockbuster, config: config))),
          icon: const Icon(Icons.preview_rounded),
          label: const Text('Preview Virtual Store'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ExperiencePreviewScreen(
                  mode: InterfaceExperienceMode.redbox, config: config))),
          icon: const Icon(Icons.preview_rounded),
          label: const Text('Preview Redbox Kiosk'),
        ),
      ],
    );
  }

  Widget _buildStoreTab(VirtualStoreDesign? store) {
    if (store == null) {
      return Center(
          child: FilledButton(
              onPressed: _addStore,
              child: const Text('Create your first store')));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
            initialValue: store.id,
            decoration:
                const InputDecoration(labelText: 'Active virtual store'),
            items: config.stores
                .map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (id) async {
              setState(() {
                config.activeStoreId = id;
                config.baseStoreId = id;
              });
              await _save('Active store');
            },
          )),
          IconButton(
              tooltip: 'Create another store',
              onPressed: _addStore,
              icon: const Icon(Icons.add_business_rounded)),
        ]),
        const SizedBox(height: 10),
        Card(
            child: ListTile(
          leading: const Icon(Icons.storefront_rounded, size: 36),
          title: Text(store.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(store.greeting),
          trailing: IconButton(
              onPressed: () => _editStoreBranding(store),
              icon: const Icon(Icons.edit_rounded)),
        )),
        _sectionHeading('Store appearance'),
        DropdownButtonFormField<String>(
          initialValue: store.floorPlan,
          decoration: const InputDecoration(labelText: 'Floor plan'),
          items: const [
            DropdownMenuItem(
                value: 'Classic wide aisles',
                child: Text('Classic wide aisles')),
            DropdownMenuItem(
                value: 'Compact neighborhood store',
                child: Text('Compact neighborhood store')),
            DropdownMenuItem(
                value: 'Open floor plan', child: Text('Open floor plan')),
            DropdownMenuItem(
                value: 'Mall-style storefront',
                child: Text('Mall-style storefront')),
            DropdownMenuItem(
                value: 'Multi-room cinema shop',
                child: Text('Multi-room cinema shop')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => store.floorPlan = value);
            await _save('Floor plan');
          },
        ),
        _colorPicker(
            'Wall color', store.wallColor, (value) => store.wallColor = value),
        _colorPicker('Floor color', store.floorColor,
            (value) => store.floorColor = value),
        _colorPicker('Shelf color', store.shelfColor,
            (value) => store.shelfColor = value),
        _colorPicker('Sign / accent color', store.accentColor,
            (value) => store.accentColor = value),
        _sectionHeading('Store navigation & movement'),
        DropdownButtonFormField<String>(
          initialValue: store.navigationMode,
          decoration: const InputDecoration(labelText: 'Navigation view'),
          items: const [
            DropdownMenuItem(
                value: 'firstPerson',
                child: Text('First-person · camera view')),
            DropdownMenuItem(
                value: 'thirdPerson',
                child: Text('Third-person · visible walker')),
            DropdownMenuItem(
                value: 'easyBrowse',
                child: Text('Easy Browse · no walking character')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => store.navigationMode = value);
            await _save('Store navigation view');
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: store.animationLevel,
          decoration: const InputDecoration(labelText: 'Animation intensity'),
          items: const [
            DropdownMenuItem(value: 'full', child: Text('Full animations')),
            DropdownMenuItem(
                value: 'reduced', child: Text('Reduced animations')),
            DropdownMenuItem(value: 'minimal', child: Text('Minimal motion')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => store.animationLevel = value);
            await _save('Store animation setting');
          },
        ),
        DropdownButtonFormField<int>(
          initialValue: store.movementSpeed.clamp(1, 5).toInt(),
          decoration: const InputDecoration(labelText: 'Walking speed'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 · Slow and relaxed')),
            DropdownMenuItem(value: 2, child: Text('2 · Leisurely')),
            DropdownMenuItem(value: 3, child: Text('3 · Normal')),
            DropdownMenuItem(value: 4, child: Text('4 · Fast')),
            DropdownMenuItem(value: 5, child: Text('5 · Very fast')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => store.movementSpeed = value);
            await _save('Store walking speed');
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: store.showWallPosters,
          onChanged: (value) async {
            setState(() => store.showWallPosters = value);
            await _save('Store wall posters');
          },
          title: const Text('Show wall posters and standees'),
          subtitle: const Text(
              'Frame owned-media artwork on the walls around the store.'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: store.showHangingBanners,
          onChanged: (value) async {
            setState(() => store.showHangingBanners = value);
            await _save('Store hanging banners');
          },
          title: const Text('Show hanging aisle banners'),
          subtitle: const Text(
              'Display category signs above aisles, not as a rotating hero banner.'),
        ),
        DropdownButtonFormField<String>(
          initialValue: store.collectionGalleryPlacement,
          decoration: const InputDecoration(
              labelText: 'Physical collection gallery location'),
          items: const [
            DropdownMenuItem(
                value: 'Center island', child: Text('Center island')),
            DropdownMenuItem(value: 'Back wall', child: Text('Back wall')),
            DropdownMenuItem(
                value: 'Front display', child: Text('Front display')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => store.collectionGalleryPlacement = value);
            await _save('Collection gallery placement');
          },
        ),
        _sectionHeading('Your aisles and shelves'),
        const Text(
            'Create any aisle you like: Marvel, Mexican Cinema, USA, Canada, Spain, decades, genres, directors, or your own favorites. Rules populate shelves from indexed metadata; manual picks remain available too.'),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          itemCount: store.aisles.length,
          onReorderItem: (oldIndex, newIndex) async {
            setState(() {
              final aisle = store.aisles.removeAt(oldIndex);
              store.aisles.insert(newIndex, aisle);
            });
            await _save('Aisle order');
          },
          itemBuilder: (context, index) {
            final aisle = store.aisles[index];
            final titles = _titlesForRule(
                filterType: aisle.filterType,
                filterValue: aisle.filterValue,
                manualIds: aisle.mediaIds);
            return Card(
              key: ValueKey(aisle.id),
              child: ExpansionTile(
                leading: const Icon(Icons.drag_indicator_rounded),
                title: Text(aisle.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${titles.length} matched titles · ${aisle.shelves.length} shelves · ${aisle.filterType}: ${aisle.filterValue}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  Text(aisle.description),
                  Wrap(spacing: 8, children: [
                    TextButton.icon(
                        onPressed: () => _editAisle(aisle),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit name')),
                    TextButton.icon(
                        onPressed: () async {
                          final filter = await _filterDialog(
                              initialType: aisle.filterType,
                              initialValue: aisle.filterValue);
                          if (filter == null) return;
                          setState(() {
                            aisle.filterType = filter['type']!;
                            aisle.filterValue = filter['value']!;
                          });
                          await _save('Aisle rule');
                        },
                        icon: const Icon(Icons.filter_alt),
                        label: const Text('Content rule')),
                    TextButton.icon(
                        onPressed: () => _pickMedia(
                            destination: aisle.mediaIds,
                            title: 'Select titles for ${aisle.name}'),
                        icon: const Icon(Icons.video_library),
                        label: const Text('Pick titles')),
                    TextButton.icon(
                        onPressed: () => _addShelf(aisle),
                        icon: const Icon(Icons.add),
                        label: const Text('Add shelf')),
                    TextButton.icon(
                        onPressed: () async {
                          setState(() => store.aisles
                              .removeWhere((entry) => entry.id == aisle.id));
                          await _save('Aisle removal');
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove')),
                  ]),
                  if (aisle.shelves.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: aisle.shelves.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        setState(() {
                          final shelf = aisle.shelves.removeAt(oldIndex);
                          aisle.shelves.insert(newIndex, shelf);
                        });
                        await _save('Shelf order');
                      },
                      itemBuilder: (context, shelfIndex) {
                        final shelf = aisle.shelves[shelfIndex];
                        final matched = _titlesForRule(
                                filterType: shelf.filterType,
                                filterValue: shelf.filterValue,
                                manualIds: shelf.mediaIds)
                            .length;
                        return ListTile(
                          key: ValueKey(shelf.id),
                          leading: const Icon(Icons.video_library_rounded),
                          title: Text(shelf.title),
                          subtitle: Text(
                              '$matched titles · ${shelf.filterType}: ${shelf.filterValue}'),
                          trailing: Wrap(children: [
                            IconButton(
                                icon: const Icon(Icons.filter_alt_outlined),
                                tooltip: 'Edit shelf rule',
                                onPressed: () async {
                                  final filter = await _filterDialog(
                                      initialType: shelf.filterType,
                                      initialValue: shelf.filterValue);
                                  if (filter == null) return;
                                  setState(() {
                                    shelf.filterType = filter['type']!;
                                    shelf.filterValue = filter['value']!;
                                  });
                                  await _save('Shelf rule');
                                }),
                            IconButton(
                                icon: const Icon(Icons.video_library_outlined),
                                tooltip: 'Choose shelf titles',
                                onPressed: () => _pickMedia(
                                    destination: shelf.mediaIds,
                                    title: 'Choose titles for ${shelf.title}')),
                          ]),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
        FilledButton.icon(
            onPressed: _addAisle,
            icon: const Icon(Icons.add_road_rounded),
            label: const Text('Add aisle')),
        _sectionHeading('Curated digital collections'),
        const Text(
          'Digital collections group titles without pretending to be physical box sets. Physical editions are detected separately from your owned-media release metadata.',
        ),
        for (final collection in store.curatedCollections)
          Card(
            child: ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(collection.title),
              subtitle: Text(
                  '${collection.mediaIds.length} titles · Digital collection'),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Edit collection contents',
                    onPressed: () =>
                        _editStoreCuratedCollection(store, collection),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove digital collection',
                    onPressed: () async {
                      setState(() => store.curatedCollections
                          .removeWhere((item) => item.id == collection.id));
                      await _save('Digital collection removed');
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _addStoreCuratedCollection(store),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Create digital collection'),
        ),
        _sectionHeading('Floor layout & decorations'),
        const Text(
            'Arrange wall posters, overhead banners, standees, shelves and decorations around the floor plan. Use the lower-right handle to resize an element.'),
        StoreFloorPlanEditor(
          elements: store.layoutElements,
          accentColor: store.accentColor,
          onChanged: () => _save('Floor plan layout'),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: store.layoutElements.length,
          onReorderItem: (oldIndex, newIndex) async {
            setState(() {
              final item = store.layoutElements.removeAt(oldIndex);
              store.layoutElements.insert(newIndex, item);
            });
            await _save('Floor layout');
          },
          itemBuilder: (context, index) {
            final item = store.layoutElements[index];
            return ListTile(
                key: ValueKey(item['id']),
                leading: const Icon(Icons.drag_indicator),
                title: Text(item['label']?.toString() ?? 'Layout item'),
                subtitle: Text(item['type']?.toString() ?? 'element'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      setState(() => store.layoutElements.removeAt(index));
                      await _save('Layout item');
                    }));
          },
        ),
        OutlinedButton.icon(
            onPressed: () => _addDecoration(store: true),
            icon: const Icon(Icons.add),
            label:
                const Text('Add wall poster, hanging banner, standee or sign')),
        _sectionHeading('Seasonal stores'),
        SwitchListTile(
            value: config.seasonalAutomationEnabled,
            onChanged: (value) async {
              setState(() => config.seasonalAutomationEnabled = value);
              await _save('Seasonal automation');
            },
            title: const Text('Enable seasonal design schedules'),
            subtitle: const Text(
                'Keep your regular store and activate saved designs during selected dates.')),
        for (final rule in store.seasonalRules)
          ListTile(
              leading: const Icon(Icons.event),
              title: Text(rule['name']?.toString() ?? 'Seasonal design'),
              subtitle: Text('${rule['start']} to ${rule['end']}')),
        OutlinedButton.icon(
            onPressed: () => _addSeasonalSchedule(store: true),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Schedule this store for a season')),
        _sectionHeading('Templates & version history'),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: () => _saveTemplate('store'),
              icon: const Icon(Icons.save_as),
              label: const Text('Save as template')),
          OutlinedButton.icon(
              onPressed: () => _restoreRevision(store: true),
              icon: const Icon(Icons.history),
              label: const Text('Restore version')),
          OutlinedButton.icon(
              onPressed: () => _save('Manual checkpoint'),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Create checkpoint')),
        ]),
        for (final template
            in config.savedTemplates.where((item) => item['kind'] == 'store'))
          ListTile(
              title: Text(template['name']?.toString() ?? 'Store template'),
              subtitle: const Text('Saved store design'),
              trailing: TextButton(
                  onPressed: () async {
                    final data = template['design'];
                    if (data is! Map) return;
                    final restored = VirtualStoreDesign.fromJson(
                        Map<String, dynamic>.from(data));
                    restored.checkpoint('Before template ${template['name']}');
                    setState(() {
                      config.stores.add(restored);
                      config.activeStoreId = restored.id;
                      config.baseStoreId = restored.id;
                    });
                    await _save('Template applied');
                  },
                  child: const Text('Apply'))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildKioskTab(KioskDesign? kiosk) {
    if (kiosk == null) {
      return Center(
          child: FilledButton(
              onPressed: _addKiosk,
              child: const Text('Create your first kiosk')));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
                  initialValue: kiosk.id,
                  decoration:
                      const InputDecoration(labelText: 'Active kiosk design'),
                  items: config.kiosks
                      .map((item) => DropdownMenuItem(
                          value: item.id, child: Text(item.name)))
                      .toList(),
                  onChanged: (id) async {
                    setState(() {
                      config.activeKioskId = id;
                      config.baseKioskId = id;
                    });
                    await _save('Active kiosk');
                  })),
          IconButton(
              tooltip: 'Create another kiosk',
              onPressed: _addKiosk,
              icon: const Icon(Icons.add_box_rounded)),
        ]),
        Card(
            child: ListTile(
                leading: const Icon(Icons.dns_rounded, size: 36),
                title: Text(kiosk.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(kiosk.greeting),
                trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editKioskBranding(kiosk)))),
        _sectionHeading('Kiosk appearance'),
        _colorPicker('Kiosk background', kiosk.backgroundColor,
            (value) => kiosk.backgroundColor = value),
        _colorPicker('Kiosk accent', kiosk.accentColor,
            (value) => kiosk.accentColor = value),
        DropdownButtonFormField<String>(
            initialValue: kiosk.layoutStyle,
            decoration: const InputDecoration(labelText: 'Display arrangement'),
            items: const [
              DropdownMenuItem(
                  value: 'Featured banner + grid',
                  child: Text('Featured banner + grid')),
              DropdownMenuItem(
                  value: 'Horizontal carousels',
                  child: Text('Horizontal carousels')),
              DropdownMenuItem(
                  value: 'Poster wall', child: Text('Poster wall')),
              DropdownMenuItem(
                  value: 'Compact list', child: Text('Compact list'))
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => kiosk.layoutStyle = value);
              await _save('Kiosk layout');
            }),
        DropdownButtonFormField<String>(
            initialValue: kiosk.screensaver,
            decoration: const InputDecoration(labelText: 'Screensaver'),
            items: const [
              DropdownMenuItem(
                  value: 'Rotating posters', child: Text('Rotating posters')),
              DropdownMenuItem(
                  value: 'Featured collections',
                  child: Text('Featured collections')),
              DropdownMenuItem(
                  value: 'Custom background', child: Text('Custom background')),
              DropdownMenuItem(value: 'Off', child: Text('Off'))
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => kiosk.screensaver = value);
              await _save('Screensaver');
            }),
        SwitchListTile(
            value: kiosk.fullScreen,
            onChanged: (value) async {
              setState(() => kiosk.fullScreen = value);
              await _save('Kiosk full-screen setting');
            },
            title: const Text('Full-screen kiosk mode')),
        SwitchListTile(
            value: kiosk.autoplayPreviews,
            onChanged: (value) async {
              setState(() => kiosk.autoplayPreviews = value);
              await _save('Kiosk preview setting');
            },
            title: const Text('Autoplay previews'),
            subtitle: const Text('Off by default to avoid unexpected audio.')),
        _sectionHeading('Categories & navigation order'),
        const Text(
            'Create and order your own kiosk categories. Each can show manually selected titles or automatically match genres, countries, franchises, studios, decades and other library metadata.'),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: kiosk.categories.length,
          onReorderItem: (oldIndex, newIndex) async {
            setState(() {
              final category = kiosk.categories.removeAt(oldIndex);
              kiosk.categories.insert(newIndex, category);
            });
            await _save('Kiosk navigation order');
          },
          itemBuilder: (context, index) {
            final category = kiosk.categories[index];
            final count = _titlesForRule(
                    filterType: category.filterType,
                    filterValue: category.filterValue,
                    manualIds: category.mediaIds)
                .length;
            return Card(
                key: ValueKey(category.id),
                child: SwitchListTile(
                  secondary: Wrap(spacing: 0, children: [
                    ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_indicator))),
                    IconButton(
                        icon: Icon(category.featured
                            ? Icons.star
                            : Icons.star_outline),
                        tooltip: 'Toggle featured',
                        onPressed: () async {
                          setState(
                              () => category.featured = !category.featured);
                          await _save('Featured category');
                        }),
                    IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Edit category',
                        onPressed: () async {
                          final name = await _textDialog(
                              title: 'Category name', initial: category.title);
                          if (name == null || name.isEmpty) return;
                          final desc = await _textDialog(
                              title: 'Category description',
                              initial: category.description);
                          final filter = await _filterDialog(
                              initialType: category.filterType,
                              initialValue: category.filterValue);
                          setState(() {
                            category.title = name;
                            if (desc != null) category.description = desc;
                            if (filter != null) {
                              category.filterType = filter['type']!;
                              category.filterValue = filter['value']!;
                            }
                          });
                          await _save('Kiosk category');
                        }),
                    IconButton(
                        icon: const Icon(Icons.video_library_outlined),
                        tooltip: 'Choose titles',
                        onPressed: () => _pickMedia(
                            destination: category.mediaIds,
                            title: 'Choose titles for ${category.title}')),
                  ]),
                  value: category.visible,
                  onChanged: (value) async {
                    setState(() => category.visible = value);
                    await _save('Kiosk category visibility');
                  },
                  title: Text(category.title),
                  subtitle: Text(
                      '$count titles · ${category.filterType}: ${category.filterValue}'),
                ));
          },
        ),
        FilledButton.icon(
            onPressed: _addKioskCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add kiosk category')),
        OutlinedButton.icon(
            onPressed: () => _addDecoration(store: false),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add kiosk decoration / banner')),
        _sectionHeading('Templates & version history'),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: () => _saveTemplate('kiosk'),
              icon: const Icon(Icons.save_as),
              label: const Text('Save as template')),
          OutlinedButton.icon(
              onPressed: () => _restoreRevision(store: false),
              icon: const Icon(Icons.history),
              label: const Text('Restore version')),
          OutlinedButton.icon(
              onPressed: () => _save('Manual checkpoint'),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Create checkpoint')),
        ]),
        for (final template
            in config.savedTemplates.where((item) => item['kind'] == 'kiosk'))
          ListTile(
              title: Text(template['name']?.toString() ?? 'Kiosk template'),
              subtitle: const Text('Saved kiosk design'),
              trailing: TextButton(
                  onPressed: () async {
                    final data = template['design'];
                    if (data is! Map) return;
                    final restored =
                        KioskDesign.fromJson(Map<String, dynamic>.from(data));
                    restored.checkpoint('Before template ${template['name']}');
                    setState(() {
                      config.kiosks.add(restored);
                      config.activeKioskId = restored.id;
                      config.baseKioskId = restored.id;
                    });
                    await _save('Kiosk template applied');
                  },
                  child: const Text('Apply'))),
        _sectionHeading('Seasonal kiosk'),
        SwitchListTile(
            value: config.seasonalAutomationEnabled,
            onChanged: (value) async {
              setState(() => config.seasonalAutomationEnabled = value);
              await _save('Seasonal automation');
            },
            title: const Text('Enable seasonal scheduling')),
        for (final rule in kiosk.seasonalRules)
          ListTile(
              leading: const Icon(Icons.event),
              title: Text(rule['name']?.toString() ?? 'Seasonal kiosk'),
              subtitle: Text('${rule['start']} to ${rule['end']}')),
        OutlinedButton.icon(
            onPressed: () => _addSeasonalSchedule(store: false),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Schedule kiosk season')),
      ],
    );
  }

  Widget _buildCollectionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Collections that work everywhere',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'Aisles, kiosk categories and Classic UI can reference the same library titles. Smart rules are evaluated against metadata that is actually indexed; missing metadata is not guessed.'),
        _sectionHeading('Automatic store management'),
        DropdownButtonFormField<String>(
            initialValue: config.autoOrganizationMode,
            decoration:
                const InputDecoration(labelText: 'New media organization'),
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('Manual only')),
              DropdownMenuItem(
                  value: 'suggest',
                  child: Text('Suggest aisle and shelf placement')),
              DropdownMenuItem(
                  value: 'auto',
                  child: Text('Automatically place when rules match'))
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => config.autoOrganizationMode = value);
              await _save('Automatic organization');
            }),
        SwitchListTile(
            value: config.autoSuggestArtwork,
            onChanged: (value) async {
              setState(() => config.autoSuggestArtwork = value);
              await _save('Artwork suggestions');
            },
            title: const Text('Suggest matching case artwork')),
        SwitchListTile(
            value: config.autoSuggestAislePlacement,
            onChanged: (value) async {
              setState(() => config.autoSuggestAislePlacement = value);
              await _save('Aisle suggestions');
            },
            title: const Text('Suggest aisle placement for new imports')),
        SwitchListTile(
            value: config.requireApproval,
            onChanged: (value) async {
              setState(() => config.requireApproval = value);
              await _save('Approval setting');
            },
            title: const Text(
                'Require approval before applying organization changes')),
        _sectionHeading('Case & cover artwork designer'),
        const Text(
            'Create your own presentation formats: VHS, DVD, Blu-ray, 4K Ultra HD or completely custom cases. Each design supports separate front, spine, back and disc-label text.'),
        if (config.caseDesigns.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: config.activeCaseDesignId != null &&
                    config.caseDesigns.any((design) =>
                        design['id']?.toString() == config.activeCaseDesignId)
                ? config.activeCaseDesignId
                : config.caseDesigns.first['id']?.toString(),
            decoration: const InputDecoration(
                labelText: 'Case style used in the Virtual Store'),
            items: config.caseDesigns
                .map((design) => DropdownMenuItem(
                    value: design['id']?.toString(),
                    child: Text('${design['name']} · ${design['format']}')))
                .toList(),
            onChanged: (id) async {
              if (id == null) return;
              setState(() => config.activeCaseDesignId = id);
              await _save('Active case style');
            },
          ),
        for (final design in config.caseDesigns)
          Card(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(
                  width: 58,
                  height: 82,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child:
                          (design['frontArtUrl']?.toString().isNotEmpty == true)
                              ? Image.network(design['frontArtUrl'].toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _casePlaceholder(design))
                              : _casePlaceholder(design))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(design['name']?.toString() ?? 'Case design',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '${design['format']} · Front / spine / back / disc label'),
                    Text('Spine: ${design['spineText'] ?? ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Disc: ${design['discLabel'] ?? ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
              IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editCaseDesign(design)),
            ]),
          )),
        OutlinedButton.icon(
            onPressed: _addCaseDesign,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Create case design')),
        _sectionHeading('Shared customization notes'),
        const ListTile(
            leading: Icon(Icons.sync),
            title: Text('One source of truth'),
            subtitle: Text(
                'The Classic UI, Virtual Store, Redbox Kiosk and Theater all use the same library and playback routes.')),
        const ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('Metadata-powered shelves'),
            subtitle: Text(
                'Country, studio, franchise, genre, decade and tag rules are dynamic when those fields exist in your catalog.')),
      ],
    );
  }

  Widget _buildOwnershipAndTheaterTab() {
    final controller = AppController.instance;
    final owned = controller.library
        .where((item) => controller.isOwned(item.id))
        .toList(growable: false);
    bool isMusic(String raw) {
      final type = raw.toLowerCase().replaceAll('_', ' ').trim();
      return type.contains('music') ||
          type.contains('song') ||
          type.contains('track') ||
          type.contains('album');
    }

    final movieCount = owned.where((item) {
      final type = item.type.toLowerCase();
      return !isMusic(item.type) &&
          (type.contains('movie') ||
              type.contains('film') ||
              type.contains('special'));
    }).length;
    final televisionCount = owned.where((item) {
      final type = item.type.toLowerCase();
      return !isMusic(item.type) &&
          (type.contains('tv') ||
              type.contains('show') ||
              type.contains('series') ||
              type.contains('episode') ||
              type.contains('special'));
    }).length;
    final musicCount = owned.where((item) => isMusic(item.type)).length;
    final discCollections = owned
        .map((item) => item.physicalReleaseId?.trim().isNotEmpty == true
            ? item.physicalReleaseId!.trim()
            : (item.discCollectionId?.trim() ?? ''))
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Your owned library',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
            'The Virtual Store, Redbox-style Kiosk and Theater are presentation modes for media you already own. They do not rent, sell or charge for playback.'),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.verified_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Owned media · ready to play',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                    'Every shelf and kiosk category is filled from the current profile’s accessible library. Selecting a title opens its normal details and playback flow.'),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text('${owned.length} owned titles')),
                  Chip(label: Text('$movieCount movies / specials')),
                  Chip(label: Text('$televisionCount TV items')),
                  Chip(label: Text('$musicCount music items')),
                  Chip(label: Text('$discCollections disc collections')),
                ]),
              ],
            ),
          ),
        ),
        _sectionHeading('Virtual Store & Kiosk rules'),
        const ListTile(
          leading: Icon(Icons.storefront_rounded),
          title: Text('Browse the collection, not a rental catalog'),
          subtitle: Text(
              'Aisles, featured shelves, box sets and seasonal displays only show titles the active profile can access.'),
        ),
        const ListTile(
          leading: Icon(Icons.touch_app_rounded),
          title: Text('Select to view or play'),
          subtitle: Text(
              'There is no rent button, return box, checkout basket, purchase price or playback paywall.'),
        ),
        const ListTile(
          leading: Icon(Icons.tv_rounded),
          title: Text('Remote-friendly kiosk'),
          subtitle: Text(
              'Directional navigation is for browsing on a TV or remote. Selecting a title uses your existing media details and player.'),
        ),
        _sectionHeading('Private home theater'),
        const Text(
            'Create a cinema-style introduction to playback. Showtimes, seat reservations and paid tickets are intentionally not part of this private theater.'),
        SwitchListTile(
            value: config.theaterCountdown,
            onChanged: (value) async {
              setState(() => config.theaterCountdown = value);
              await _save('Theater countdown');
            },
            title: const Text('Show a countdown before playback')),
        SwitchListTile(
            value: config.theaterTrailers,
            onChanged: (value) async {
              setState(() => config.theaterTrailers = value);
              await _save('Theater trailers');
            },
            title: const Text('Play available trailers before the feature')),
        SwitchListTile(
            value: config.theaterAmbience,
            onChanged: (value) async {
              setState(() => config.theaterAmbience = value);
              await _save('Theater ambience');
            },
            title: const Text('Optional theater ambience')),
        FilledButton.icon(
            onPressed: () => _launchExperience(InterfaceExperienceMode.theater),
            icon: const Icon(Icons.theaters),
            label: const Text('Open Private Theater mode')),
        _sectionHeading('TV remote navigation'),
        SwitchListTile(
            value: config.remoteNavigationEnabled,
            onChanged: (value) async {
              setState(() => config.remoteNavigationEnabled = value);
              await _save('Remote navigation');
            },
            title: const Text('Enable remote-friendly focus navigation')),
        const Text(
            'Kiosk cards and buttons use Flutter focus traversal so directional-pad remotes and keyboard arrows can move between controls. Playback still uses your existing player.'),
      ],
    );
  }

  Widget _sectionHeading(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _colorPicker(String label, int color, ValueChanged<int> update) {
    const options = <int>[
      0xFF101820,
      0xFF1B1B1B,
      0xFF292522,
      0xFF4E342E,
      0xFFB71C1C,
      0xFF1565C0,
      0xFF2E7D32,
      0xFF512DA8,
      0xFFFFC107,
      0xFFE53935,
      0xFF00897B,
      0xFFEEEEEE
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<int>(
        value: options.contains(color) ? color : options.first,
        onChanged: (value) async {
          if (value == null) return;
          setState(() => update(value));
          await _save(label);
        },
        items: options
            .map((value) => DropdownMenuItem(
                value: value,
                child: Row(children: [
                  Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: Color(value),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24))),
                  const SizedBox(width: 8),
                  Text('#${value.toRadixString(16).substring(2).toUpperCase()}')
                ])))
            .toList(),
      ),
    );
  }

  Widget _casePlaceholder(Map<String, dynamic> design) => Container(
        color: Color(_intOrDefault(design['primaryColor'], 0xFF123D74)),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Text(design['frontTitle']?.toString() ?? 'MOVIE',
            maxLines: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
      );

  int _intOrDefault(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

class StoreFloorPlanEditor extends StatefulWidget {
  const StoreFloorPlanEditor(
      {super.key,
      required this.elements,
      required this.accentColor,
      required this.onChanged});
  final List<Map<String, dynamic>> elements;
  final int accentColor;
  final VoidCallback onChanged;

  @override
  State<StoreFloorPlanEditor> createState() => _StoreFloorPlanEditorState();
}

class _StoreFloorPlanEditorState extends State<StoreFloorPlanEditor> {
  double _number(Map<String, dynamic> item, String key, double fallback) =>
      item[key] is num ? (item[key] as num).toDouble() : fallback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const height = 250.0;
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Color(widget.accentColor).withValues(alpha: .8), width: 2),
        ),
        child: Stack(children: [
          for (var index = 0; index < widget.elements.length; index++)
            _buildElement(index, width, height),
          const Positioned(
              left: 8,
              bottom: 6,
              child: Text('STORE FLOOR PLAN · DRAG TO MOVE · CORNER TO RESIZE',
                  style: TextStyle(fontSize: 9, color: Colors.white54))),
        ]),
      );
    });
  }

  Widget _buildElement(int index, double boardWidth, double boardHeight) {
    final item = widget.elements[index];
    final fallbackX = 0.04 + (index % 3) * 0.30;
    final fallbackY = 0.08 + ((index ~/ 3) % 2) * 0.42;
    final x = _number(item, 'x', fallbackX).clamp(0.0, 0.85).toDouble();
    final w = _number(item, 'width', 0.25).clamp(0.12, 0.72).toDouble();
    final h = _number(item, 'height', 0.24).clamp(0.12, 0.55).toDouble();
    final y = _number(item, 'y', fallbackY).clamp(0.0, 1.0 - h).toDouble();
    return Positioned(
      left: x * boardWidth,
      top: y * boardHeight,
      width: w * boardWidth,
      height: h * boardHeight,
      child: Stack(children: [
        Positioned.fill(
            child: GestureDetector(
          onPanUpdate: (details) => setState(() {
            item['x'] = (x + details.delta.dx / boardWidth).clamp(0.0, 1.0 - w);
            item['y'] =
                (y + details.delta.dy / boardHeight).clamp(0.0, 1.0 - h);
          }),
          onPanEnd: (_) => widget.onChanged(),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Color(widget.accentColor).withValues(alpha: .20),
              border: Border.all(color: Color(widget.accentColor), width: 1.4),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(item['label']?.toString() ?? 'Layout element',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        )),
        Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) => setState(() {
                item['width'] =
                    (w + details.delta.dx / boardWidth).clamp(0.12, 0.8);
                item['height'] =
                    (h + details.delta.dy / boardHeight).clamp(0.12, 0.65);
              }),
              onPanEnd: (_) => widget.onChanged(),
              child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: Color(widget.accentColor),
                      borderRadius:
                          const BorderRadius.only(topLeft: Radius.circular(5))),
                  child: const Icon(Icons.open_in_full,
                      size: 11, color: Colors.black)),
            )),
      ]),
    );
  }
}

class ExperiencePreviewScreen extends StatelessWidget {
  const ExperiencePreviewScreen(
      {super.key, required this.mode, required this.config});

  final InterfaceExperienceMode mode;
  final InterfaceExperienceConfig config;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case InterfaceExperienceMode.blockbuster:
        return VirtualStoreExperienceScreen(config: config);
      case InterfaceExperienceMode.redbox:
        return const RedboxHomeScreen();
      case InterfaceExperienceMode.theater:
        return const TheaterHomeScreen();
      case InterfaceExperienceMode.classic:
        return const Scaffold(
            body: Center(
                child: Text(
                    'Return to Classic Home from the Experience Studio.')));
    }
  }
}
