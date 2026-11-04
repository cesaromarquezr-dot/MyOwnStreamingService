import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'interface_experience.dart';

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
    final store = VirtualStoreDesign(name: name);
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
    final kiosk = KioskDesign(name: name);
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
        title: 'Decoration or layout item',
        hint: 'e.g. Neon Marvel sign, popcorn machine, poster stand');
    if (!mounted || label == null || label.isEmpty) return;
    final item = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'type': 'decoration',
      'label': label,
      'x': 0.5,
      'y': 0.5,
      'width': 0.18,
      'height': 0.12,
    };
    setState(() {
      if (store) {
        config.activeStore?.layoutElements.add(item);
      } else {
        config.activeKiosk?.decorations.add(item);
      }
    });
    await _save('Decoration');
  }

  Future<void> _pickMedia(
      {required List<String> destination, required String title}) async {
    final library = AppController.instance.library
        .where((item) => AppController.instance.isOwned(item.id))
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

  Future<void> _checkoutBasket() async {
    if (config.rentalBasket.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final ids = List<String>.from(config.rentalBasket);
    setState(() {
      config.currentRentals
          .addAll(ids.where((id) => !config.currentRentals.contains(id)));
      config.rentalHistory.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'action': 'checkout',
        'mediaIds': ids,
        'timestamp': now,
      });
      config.rentalBasket.clear();
    });
    await _save('Rental checkout');
  }

  Future<void> _returnRental(String mediaId) async {
    setState(() {
      config.currentRentals.remove(mediaId);
      config.rentalHistory.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'action': 'return',
        'mediaIds': [mediaId],
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    });
    await _save('Rental return');
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
                text: 'Rentals & Theater'),
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
          _buildRentalAndTheaterTab(),
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
                          leading: const Icon(Icons.shelves),
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
        _sectionHeading('Floor layout & decorations'),
        const Text(
            'Drag shelves, signs and decorations around the floor plan. Use the lower-right handle to resize an element.'),
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
            label: const Text('Add sign, poster, standee or decoration')),
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

  Widget _buildRentalAndTheaterTab() {
    final library = AppController.instance.library
        .where((item) => AppController.instance.isOwned(item.id))
        .toList();
    MediaItem? find(String id) {
      for (final item in library) {
        if (item.id == id) return item;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Virtual rental experience',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'This is a fun library presentation layer—not DRM and not a real restriction on your files.'),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.membershipName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('Membership card · ${config.membershipNumber}'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: () async {
                            final name = await _textDialog(
                                title: 'Membership name',
                                initial: config.membershipName);
                            final number = await _textDialog(
                                title: 'Membership number',
                                initial: config.membershipNumber);
                            if (!mounted) return;
                            setState(() {
                              if (name != null && name.isNotEmpty) {
                                config.membershipName = name;
                              }
                              if (number != null && number.isNotEmpty) {
                                config.membershipNumber = number;
                              }
                            });
                            await _save('Membership card');
                          },
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Customize membership card')),
                    ]))),
        _sectionHeading('My rental basket'),
        for (final id in config.rentalBasket)
          ListTile(
              title: Text(find(id)?.title ?? 'Unavailable library title'),
              trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    setState(() => config.rentalBasket.remove(id));
                    await _save('Rental basket');
                  })),
        OutlinedButton.icon(
            onPressed: () async {
              final destination = List<String>.from(config.rentalBasket);
              await _pickMedia(
                  destination: destination,
                  title: 'Add titles to rental basket');
              setState(() {
                config.rentalBasket
                  ..clear()
                  ..addAll(destination);
              });
              await _save('Rental basket');
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add titles to basket')),
        FilledButton.icon(
            onPressed: config.rentalBasket.isEmpty ? null : _checkoutBasket,
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Checkout basket')),
        _sectionHeading('My rentals & return box'),
        for (final id in config.currentRentals)
          ListTile(
              title: Text(find(id)?.title ?? 'Unavailable library title'),
              subtitle: const Text(
                  'Currently checked out in the virtual rental experience'),
              trailing: TextButton(
                  onPressed: () => _returnRental(id),
                  child: const Text('Return'))),
        if (config.currentRentals.isEmpty)
          const Text('No active virtual rentals.'),
        _sectionHeading('Rental history'),
        for (final row in config.rentalHistory.reversed.take(10))
          ListTile(
              leading: Icon(row['action'] == 'return'
                  ? Icons.assignment_return
                  : Icons.shopping_bag),
              title: Text(row['action'] == 'return'
                  ? 'Returned title'
                  : 'Checked out titles'),
              subtitle: Text(row['timestamp']?.toString() ?? '')),
        _sectionHeading('Movie theater experience'),
        const Text(
            'Optional cinema lobby, ticket-style presentation and countdown before playback. Trailers and ambience remain opt-in.'),
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
            title: const Text('Play trailers before the feature')),
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
            label: const Text('Open Movie Theater mode')),
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

  List<MediaItem> _items(String type, String value, List<String> ids) {
    final library = AppController.instance.library
        .where((item) => AppController.instance.isOwned(item.id))
        .toList();
    final query = value.toLowerCase().trim();
    Iterable<MediaItem> items = library;
    switch (type) {
      case 'manual':
        items = library.where((item) => ids.contains(item.id));
        break;
      case 'genre':
        items = library.where((item) =>
            item.genres.any((genre) => genre.toLowerCase() == query) ||
            item.primaryGenre?.toLowerCase() == query);
        break;
      case 'country':
        items = library
            .where((item) => item.countryOfOrigin?.toLowerCase() == query);
        break;
      case 'decade':
        final decade = int.tryParse(value);
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
                .any((name) => name.toLowerCase().contains(query)) ||
            item.franchiseName?.toLowerCase().contains(query) == true ||
            item.cinematicUniverseNames
                .any((name) => name.toLowerCase().contains(query)));
        break;
      case 'studio':
        items = library.where((item) =>
            item.studios.any((name) => name.toLowerCase().contains(query)));
        break;
      case 'tag':
        items = library.where(
            (item) => item.tags.any((tag) => tag.toLowerCase() == query));
        break;
      case 'recent':
        final recent = library.toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return recent.take(24).toList();
      case 'favorites':
        items = library.where((item) =>
            AppController.instance.liked.any((liked) => liked.id == item.id));
        break;
      case 'all':
        break;
    }
    return items.take(30).toList();
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case InterfaceExperienceMode.blockbuster:
        return _StorePreview(
            store: config.activeStore,
            items: _items,
            caseDesign: config.activeCaseDesign);
      case InterfaceExperienceMode.redbox:
        return _KioskPreview(kiosk: config.activeKiosk, items: _items);
      case InterfaceExperienceMode.theater:
        return _TheaterPreview(config: config, items: _items);
      case InterfaceExperienceMode.classic:
        return const Scaffold(
            body: Center(
                child: Text(
                    'Return to Classic Home from the Experience Studio.')));
    }
  }
}

typedef _RuleItems = List<MediaItem> Function(String, String, List<String>);

class _StorePreview extends StatelessWidget {
  const _StorePreview(
      {required this.store, required this.items, this.caseDesign});
  final VirtualStoreDesign? store;
  final _RuleItems items;
  final Map<String, dynamic>? caseDesign;

  @override
  Widget build(BuildContext context) {
    final design = store;
    if (design == null) {
      return const Scaffold(
          body: Center(
              child: Text('Create a store in the Experience Studio first.')));
    }
    return Scaffold(
      backgroundColor: Color(design.wallColor),
      appBar: AppBar(
          backgroundColor: Color(design.shelfColor),
          title: Text(design.name),
          actions: [
            IconButton(
                tooltip: 'Edit design',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.design_services))
          ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Color(design.shelfColor),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Color(design.accentColor), width: 2)),
              child: Column(children: [
                if (design.logoUrl.isNotEmpty)
                  Image.network(design.logoUrl,
                      height: 54,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                Text(design.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(design.accentColor))),
                const SizedBox(height: 6),
                Text(design.greeting, textAlign: TextAlign.center)
              ])),
          const SizedBox(height: 12),
          for (final aisle in design.aisles) ...[
            Row(children: [
              Container(
                  width: 8,
                  height: 26,
                  decoration: BoxDecoration(
                      color: Color(aisle.color),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(aisle.name,
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(design.accentColor))))
            ]),
            if (aisle.description.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(left: 17, top: 3, bottom: 4),
                  child: Text(aisle.description,
                      style: const TextStyle(color: Colors.white70))),
            _MediaPosterRow(
                items:
                    items(aisle.filterType, aisle.filterValue, aisle.mediaIds),
                emptyLabel: 'No matching titles in this aisle yet.',
                caseDesign: caseDesign),
            for (final shelf in aisle.shelves) ...[
              Padding(
                  padding: const EdgeInsets.only(left: 17, top: 6),
                  child: Text('↳ ${shelf.title}',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              _MediaPosterRow(
                  items: items(
                      shelf.filterType, shelf.filterValue, shelf.mediaIds),
                  emptyLabel: 'No titles in this shelf yet.',
                  caseDesign: caseDesign),
            ],
          ],
          if (design.aisles.isEmpty)
            const Center(
                child: Text(
                    'Your store is ready. Add aisles in the Experience Studio.')),
          if (design.layoutElements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Store floor plan · ${design.floorPlan}',
                style: TextStyle(
                    color: Color(design.accentColor),
                    fontWeight: FontWeight.bold)),
            _StoreLayoutPreview(
                elements: design.layoutElements,
                accentColor: design.accentColor,
                floorColor: design.floorColor),
          ],
        ],
      ),
    );
  }
}

class _KioskPreview extends StatelessWidget {
  const _KioskPreview({required this.kiosk, required this.items});
  final KioskDesign? kiosk;
  final _RuleItems items;

  @override
  Widget build(BuildContext context) {
    final design = kiosk;
    if (design == null) {
      return const Scaffold(
          body: Center(
              child: Text(
                  'Create a kiosk design in the Experience Studio first.')));
    }
    final categories =
        design.categories.where((category) => category.visible).toList();
    return Scaffold(
      backgroundColor: Color(design.backgroundColor),
      appBar: AppBar(
          backgroundColor: Color(design.backgroundColor),
          title: Text(design.name),
          actions: [
            IconButton(
                tooltip: 'Edit kiosk',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.tune))
          ]),
      body: FocusTraversalGroup(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Color(design.accentColor).withValues(alpha: .9),
                    Color(design.backgroundColor)
                  ]),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                if (design.logoUrl.isNotEmpty)
                  Image.network(design.logoUrl,
                      height: 46,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                Text(design.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(design.greeting)
              ])),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerRight,
              child: Chip(
                  avatar: const Icon(Icons.view_quilt, size: 16),
                  label: Text(design.layoutStyle))),
          for (final category in categories) ...[
            Row(children: [
              Expanded(
                  child: Text(category.title,
                      style: TextStyle(
                          color: Color(design.accentColor),
                          fontSize: 20,
                          fontWeight: FontWeight.bold))),
              if (category.featured) const Chip(label: Text('Featured'))
            ]),
            if (category.description.isNotEmpty)
              Text(category.description,
                  style: const TextStyle(color: Colors.white70)),
            _KioskCategoryLayout(
              layoutStyle: design.layoutStyle,
              accentColor: design.accentColor,
              items: items(
                  category.filterType, category.filterValue, category.mediaIds),
              emptyLabel: 'No matching titles yet.',
            ),
          ],
          if (categories.isEmpty)
            const Text(
                'No categories are visible. Configure the kiosk in the Experience Studio.'),
          if (design.decorations.isNotEmpty)
            Wrap(
                spacing: 8,
                children: design.decorations
                    .map((item) => Chip(
                        label: Text(
                            item['label']?.toString() ?? 'Kiosk decoration'),
                        avatar: const Icon(Icons.auto_awesome, size: 16)))
                    .toList()),
          const SizedBox(height: 12),
          const Text(
              'Remote-ready: use directional navigation to move between focused titles and controls.',
              style: TextStyle(color: Colors.white60)),
        ]),
      ),
    );
  }
}

class _TheaterPreview extends StatelessWidget {
  const _TheaterPreview({required this.config, required this.items});
  final InterfaceExperienceConfig config;
  final _RuleItems items;

  @override
  Widget build(BuildContext context) {
    final movies = AppController.instance.library
        .where((item) =>
            AppController.instance.isOwned(item.id) &&
            item.type.toLowerCase().contains('movie'))
        .take(40)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFF100708),
      appBar: AppBar(
          backgroundColor: const Color(0xFF100708),
          title: const Text('Movie Theater')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: const Color(0xFF391116),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amber, width: 2)),
            child: const Column(children: [
              Icon(Icons.theaters_rounded, size: 52, color: Colors.amber),
              Text('TONIGHT AT YOUR THEATER',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              SizedBox(height: 8),
              Text('Choose your feature',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
            ])),
        const SizedBox(height: 12),
        if (config.theaterCountdown)
          const ListTile(
              leading: Icon(Icons.timer),
              title: Text('Pre-show countdown enabled')),
        if (config.theaterTrailers)
          const ListTile(
              leading: Icon(Icons.movie_filter),
              title: Text(
                  'Trailer pre-show enabled (requires available trailer metadata)')),
        if (config.theaterAmbience)
          const ListTile(
              leading: Icon(Icons.surround_sound),
              title:
                  Text('Theater ambience enabled (sound assets not bundled)')),
        for (final item in movies)
          ListTile(
              leading: const Icon(Icons.local_movies),
              title: Text(item.title),
              subtitle: Text(item.releaseYear?.toString() ?? ''),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => MediaDetailsScreen(media: item)))),
        if (movies.isEmpty)
          const Text('Import movie titles to populate your theater lobby.'),
      ]),
    );
  }
}

class _StoreLayoutPreview extends StatelessWidget {
  const _StoreLayoutPreview(
      {required this.elements,
      required this.accentColor,
      required this.floorColor});
  final List<Map<String, dynamic>> elements;
  final int accentColor;
  final int floorColor;

  double _value(Map<String, dynamic> item, String key, double fallback) =>
      item[key] is num ? (item[key] as num).toDouble() : fallback;

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        decoration: BoxDecoration(
            color: Color(floorColor),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(accentColor))),
        child: LayoutBuilder(
            builder: (context, constraints) => Stack(children: [
                  for (var index = 0; index < elements.length; index++)
                    _element(elements[index], index, constraints.maxWidth),
                  const Positioned(
                      left: 8,
                      bottom: 6,
                      child: Text('ENTRANCE / AISLES / FEATURE WALL',
                          style:
                              TextStyle(fontSize: 9, color: Colors.white70))),
                ])),
      );

  Widget _element(Map<String, dynamic> item, int index, double width) {
    final x =
        _value(item, 'x', 0.04 + (index % 3) * .30).clamp(0.0, .85).toDouble();
    final y = _value(item, 'y', .08 + ((index ~/ 3) % 2) * .42)
        .clamp(0.0, .75)
        .toDouble();
    final w = _value(item, 'width', .25).clamp(.12, .8).toDouble();
    final h = _value(item, 'height', .24).clamp(.12, .6).toDouble();
    final type = item['type']?.toString() ?? 'shelves';
    final color = type == 'entrance'
        ? const Color(0xFF2E7D32)
        : type == 'featured'
            ? Color(accentColor)
            : type == 'decoration'
                ? const Color(0xFF6A1B9A)
                : const Color(0xFF5D4037);
    return Positioned(
        left: x * width,
        top: y * 220,
        width: w * width,
        height: h * 220,
        child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .85),
                border: Border.all(color: Colors.white70),
                borderRadius: BorderRadius.circular(7)),
            child: Text(item['label']?.toString() ?? type,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white))));
  }
}

class _KioskCategoryLayout extends StatelessWidget {
  const _KioskCategoryLayout(
      {required this.layoutStyle,
      required this.accentColor,
      required this.items,
      required this.emptyLabel});
  final String layoutStyle;
  final int accentColor;
  final List<MediaItem> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Text(emptyLabel, style: const TextStyle(color: Colors.white54)));
    }
    if (layoutStyle == 'Compact list') {
      return Column(children: [
        for (final item in items.take(12))
          ListTile(
            dense: true,
            focusColor: Color(accentColor).withValues(alpha: .18),
            leading: SizedBox(
                width: 42,
                child: item.imageUrl == null
                    ? const Icon(Icons.movie)
                    : Image.network(item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.movie))),
            title:
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle:
                Text(item.releaseYear?.toString() ?? item.type, maxLines: 1),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => MediaDetailsScreen(media: item))),
          ),
      ]);
    }
    if (layoutStyle == 'Featured banner + grid') {
      final featured = items.first;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: featured))),
          child: Container(
            height: 154,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Color(accentColor).withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              if (featured.imageUrl != null)
                Image.network(featured.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .88)
                  ]))),
              Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FEATURED TITLE',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white70)),
                        Text(featured.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ])),
            ]),
          ),
        ),
        if (items.length > 1)
          _KioskCategoryLayout(
              layoutStyle: 'Poster wall',
              accentColor: accentColor,
              items: items.skip(1).toList(),
              emptyLabel: emptyLabel),
      ]);
    }
    if (layoutStyle == 'Poster wall') {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.take(24).length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 10,
            childAspectRatio: .62),
        itemBuilder: (context, index) {
          final item = items[index];
          return FocusTraversalOrder(
              order: NumericFocusOrder(index.toDouble()),
              child: InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => MediaDetailsScreen(media: item))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: item.imageUrl == null
                                  ? Container(
                                      color: Color(accentColor)
                                          .withValues(alpha: .2),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.movie, size: 30))
                                  : Image.network(item.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: Colors.white12,
                                          child: const Icon(Icons.movie))))),
                      const SizedBox(height: 4),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
              ));
        },
      );
    }
    return _MediaPosterRow(items: items, emptyLabel: emptyLabel);
  }
}

Widget _caseFace(MediaItem item, Map<String, dynamic>? design) {
  final customTitle = design?['frontTitle']?.toString().trim();
  final title =
      customTitle == null || customTitle.isEmpty || customTitle == 'Movie Title'
          ? item.title
          : customTitle;
  return Container(
    color: Color(_caseColor(design?['primaryColor'], 0xFF243447)),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(7),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.local_movies, size: 30, color: Colors.white70),
      const SizedBox(height: 6),
      Text(title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );
}

int _caseColor(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

class _MediaPosterRow extends StatelessWidget {
  const _MediaPosterRow(
      {required this.items, required this.emptyLabel, this.caseDesign});
  final List<MediaItem> items;
  final String emptyLabel;
  final Map<String, dynamic>? caseDesign;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
          padding: const EdgeInsets.only(left: 17, top: 8, bottom: 14),
          child:
              Text(emptyLabel, style: const TextStyle(color: Colors.white54)));
    }
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 108,
            child: FocusTraversalOrder(
              order: NumericFocusOrder(index.toDouble()),
              child: InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => MediaDetailsScreen(media: item))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(_caseColor(
                                caseDesign?['primaryColor'], 0xFF243447)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 5,
                                  offset: Offset(2, 2))
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(fit: StackFit.expand, children: [
                              if ((caseDesign?['frontArtUrl']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false))
                                Image.network(
                                    caseDesign!['frontArtUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _caseFace(item, caseDesign))
                              else if (item.imageUrl != null)
                                Image.network(item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _caseFace(item, caseDesign))
                              else
                                _caseFace(item, caseDesign),
                              Positioned(
                                  left: 3,
                                  right: 3,
                                  top: 3,
                                  child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          color: Colors.black87,
                                          child: Text(
                                              caseDesign?['format']
                                                      ?.toString() ??
                                                  'Blu-ray',
                                              style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight:
                                                      FontWeight.bold))))),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
