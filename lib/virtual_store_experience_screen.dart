import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_core.dart' hide MediaCollection;
import 'data/collection_repository.dart';
import 'interface_experience.dart';
import 'models/media_case_style.dart';
import 'models/media_collection_models.dart';
import 'music.dart';
import 'screens/collection_details_screen.dart';
import 'details.dart';
import 'catalog_poster_image.dart';
import 'stores/collection_store.dart';
import 'widgets/animated_media_case_dialog.dart';
import 'widgets/collection_box.dart';
import 'widgets/media_case_3d_view.dart';

/// The Virtual Store is a lightweight, accessible 2.5D environment.
///
/// It deliberately uses the user's owned media as its catalog. The store has
/// no rental, checkout, payment, or purchasing flow.
class VirtualStoreExperienceScreen extends StatefulWidget {
  const VirtualStoreExperienceScreen({
    super.key,
    required this.config,
  });

  final InterfaceExperienceConfig config;

  @override
  State<VirtualStoreExperienceScreen> createState() =>
      _VirtualStoreExperienceScreenState();
}

class _VirtualStoreExperienceScreenState
    extends State<VirtualStoreExperienceScreen> {
  final FocusNode _navigationFocus = FocusNode(debugLabel: 'Virtual Store');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _collectionsKey = GlobalKey();
  final GlobalKey _playlistsKey = GlobalKey();
  final MusicLibraryStore _music = MusicLibraryStore.instance;
  final CollectionStore _collections = CollectionStore.instance;

  int _zoneIndex = 0;
  int _selectedMediaIndex = 0;
  bool _shelfOpen = false;
  String? _selectedMediaId;

  VirtualStoreDesign? get _design => widget.config.activeStore;

  @override
  void initState() {
    super.initState();
    _music.addListener(_refresh);
    _collections.addListener(_refresh);
    _collections.load();
    unawaited(_music.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
  }

  @override
  void dispose() {
    _music.removeListener(_refresh);
    _collections.removeListener(_refresh);
    _navigationFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<MediaItem> get _ownedLibrary {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) => item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList(growable: false);
  }

  List<String> get _zoneLabels {
    final aisles = _design?.aisles ?? const <StoreAisle>[];
    return <String>[
      ...aisles.map((aisle) => aisle.name),
      'Collection Gallery',
      'Listening Lounge',
    ];
  }

  int get _safeZoneIndex => _zoneIndex.clamp(0, _zoneLabels.length - 1).toInt();

  StoreAisle? get _currentAisle {
    final aisles = _design?.aisles ?? const <StoreAisle>[];
    if (_safeZoneIndex >= aisles.length) return null;
    return aisles[_safeZoneIndex];
  }

  List<MediaItem> _resolveRule({
    required String filterType,
    String filterValue = '',
    List<String> mediaIds = const <String>[],
  }) {
    final all = _ownedLibrary;
    final query = filterValue.trim().toLowerCase();
    Iterable<MediaItem> result = all;
    switch (filterType) {
      case 'manual':
        result = all.where((item) => mediaIds.contains(item.id));
        break;
      case 'genre':
        result = all.where((item) =>
            item.genres.any((genre) => genre.toLowerCase() == query) ||
            item.primaryGenre?.toLowerCase() == query);
        break;
      case 'country':
        result = all.where((item) => item.countryOfOrigin?.toLowerCase() == query);
        break;
      case 'decade':
        final decade = int.tryParse(filterValue.trim());
        if (decade != null) {
          result = all.where((item) =>
              item.releaseYear != null &&
              item.releaseYear! >= decade &&
              item.releaseYear! < decade + 10);
        }
        break;
      case 'franchise':
        result = all.where((item) =>
            item.franchiseNames.any((name) => name.toLowerCase().contains(query)) ||
            item.franchiseName?.toLowerCase().contains(query) == true ||
            item.cinematicUniverseNames.any((name) => name.toLowerCase().contains(query)));
        break;
      case 'studio':
        result = all.where((item) =>
            item.studios.any((name) => name.toLowerCase().contains(query)));
        break;
      case 'type':
        result = all.where((item) {
          final type = item.type.toLowerCase().replaceAll('_', ' ');
          if (query == 'music' || query == 'audio') {
            return type.contains('music') || type.contains('song') ||
                type.contains('track') || type.contains('album') || type.contains('audio');
          }
          if (query == 'tv' || query == 'television' || query == 'specials') {
            return type.contains('tv') || type.contains('show') ||
                type.contains('series') || type.contains('episode') || type.contains('special');
          }
          if (query == 'movie' || query == 'movies' || query == 'film') {
            return type.contains('movie') || type.contains('film') ||
                type.contains('documentary') || type.contains('concert film');
          }
          return type == query;
        });
        break;
      case 'tag':
        result = all.where((item) => item.tags.any((tag) => tag.toLowerCase() == query));
        break;
      case 'recent':
        final recent = all.toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return recent.take(40).toList(growable: false);
      case 'favorites':
        result = all.where((item) =>
            AppController.instance.liked.any((liked) => liked.id == item.id));
        break;
      case 'all':
        break;
      default:
        result = all;
    }
    return result.take(60).toList(growable: false);
  }

  List<_StoreShelfData> _shelvesFor(StoreAisle aisle) {
    final shelves = <_StoreShelfData>[
      _StoreShelfData(
        title: aisle.name,
        items: _resolveRule(
          filterType: aisle.filterType,
          filterValue: aisle.filterValue,
          mediaIds: aisle.mediaIds,
        ),
      ),
    ];
    for (final shelf in aisle.shelves) {
      shelves.add(_StoreShelfData(
        title: shelf.title,
        items: _resolveRule(
          filterType: shelf.filterType,
          filterValue: shelf.filterValue,
          mediaIds: shelf.mediaIds,
        ),
      ));
    }
    return shelves;
  }

  List<MediaItem> get _currentAisleItems {
    final aisle = _currentAisle;
    if (aisle == null) return const <MediaItem>[];
    final seen = <String>{};
    return [
      for (final shelf in _shelvesFor(aisle))
        for (final item in shelf.items)
          if (seen.add(item.id)) item,
    ];
  }

  MediaItem? get _selectedMedia {
    final items = _currentAisleItems;
    if (items.isEmpty) return null;
    if (_selectedMediaId != null) {
      for (final item in items) {
        if (item.id == _selectedMediaId) return item;
      }
    }
    final index = _selectedMediaIndex.clamp(0, items.length - 1).toInt();
    return items[index];
  }

  void _selectZone(int delta) {
    if (_zoneLabels.isEmpty) return;
    setState(() {
      _zoneIndex = (_safeZoneIndex + delta).clamp(0, _zoneLabels.length - 1).toInt();
      _shelfOpen = false;
      _selectedMediaIndex = 0;
      _selectedMediaId = null;
    });
  }

  void _cycleMedia(int delta) {
    final items = _currentAisleItems;
    if (items.isEmpty) return;
    setState(() {
      _selectedMediaIndex = (_selectedMediaIndex + delta).clamp(0, items.length - 1).toInt();
      _selectedMediaId = items[_selectedMediaIndex].id;
    });
  }

  void _openCurrentZone() {
    final aisleCount = _design?.aisles.length ?? 0;
    if (_safeZoneIndex < aisleCount) {
      setState(() {
        _shelfOpen = true;
        _selectedMediaIndex = 0;
        _selectedMediaId = _currentAisleItems.isEmpty ? null : _currentAisleItems.first.id;
      });
      return;
    }
    final target = _safeZoneIndex == aisleCount ? _collectionsKey : _playlistsKey;
    final targetContext = target.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: _motionDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  Duration get _motionDuration {
    final design = _design;
    final level = design?.animationLevel ?? 'full';
    if (level == 'minimal') return Duration.zero;
    final base = level == 'reduced' ? 180 : 320;
    final speed = (design?.movementSpeed ?? 3).clamp(1, 5);
    return Duration(milliseconds: (base * (4 - speed) / 3).round().clamp(55, base).toInt());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final isRight = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    final isUp = key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW;
    final isDown = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS;
    final isSelect = key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final isBack = key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace;

    if (_shelfOpen && _currentAisle != null) {
      if (isLeft || isUp) {
        _cycleMedia(-1);
        return KeyEventResult.handled;
      }
      if (isRight || isDown) {
        _cycleMedia(1);
        return KeyEventResult.handled;
      }
      if (isSelect) {
        _inspectSelectedMedia();
        return KeyEventResult.handled;
      }
      if (isBack) {
        setState(() => _shelfOpen = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (isLeft || isUp) {
      _selectZone(-1);
      return KeyEventResult.handled;
    }
    if (isRight || isDown) {
      _selectZone(1);
      return KeyEventResult.handled;
    }
    if (isSelect) {
      _openCurrentZone();
      return KeyEventResult.handled;
    }
    if (isBack) return KeyEventResult.ignored;
    return KeyEventResult.ignored;
  }

  Future<void> _inspectSelectedMedia() async {
    final media = _selectedMedia;
    if (media == null) return;
    final format = MediaCaseStyle.canonicalFormat(media.displayCaseFormat);
    if (format == 'Digital / not recorded') {
      _openMediaDetails(media);
      return;
    }
    await showAnimatedMediaCaseDialog(
      context,
      media: media,
      animationLevel: _design?.animationLevel ?? 'full',
      onOpenTitle: () => _openMediaDetails(media),
    );
  }

  void _openMediaDetails(MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(media: media),
      ),
    );
  }

  void _openPhysicalCollection(MediaCollection collection) {
    showAnimatedCollectionBoxDialog(
      context,
      collection: collection,
      animationLevel: _design?.animationLevel ?? 'full',
      onOpenCollection: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailsScreen(collection: collection),
        ),
      ),
    );
  }

  Future<void> _openDigitalCollection(StoreCuratedCollection collection) async {
    final items = _ownedLibrary
        .where((media) => collection.mediaIds.contains(media.id))
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(collection.title),
        content: SizedBox(
          width: 480,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (collection.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(collection.description),
                ),
              Text('${items.length} titles · Digital collection',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No matching owned titles in this collection.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: SizedBox(
                              width: 42,
                              child: CatalogPosterImage(
                                media: item,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${item.type} · ${item.releaseYear ?? 'Year unknown'}'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _openMediaDetails(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<_StorePlaylistData> get _playlists {
    final output = <_StorePlaylistData>[];
    for (final entry in _music.playlists.entries) {
      output.add(_StorePlaylistData(name: entry.key, trackIds: entry.value, isSmart: false));
    }
    for (final entry in _music.smartPlaylists.entries) {
      output.add(_StorePlaylistData(name: entry.key, trackIds: entry.value, isSmart: true));
    }
    return output.where((playlist) => playlist.trackIds.isNotEmpty).toList(growable: false);
  }

  List<MusicTrack> _tracksForPlaylist(_StorePlaylistData playlist) {
    final tracksById = <String, MusicTrack>{
      for (final track in _music.tracks) track.id: track,
      ..._music.catalogTracks,
    };
    return playlist.trackIds
        .map((id) => tracksById[id])
        .whereType<MusicTrack>()
        .toList(growable: false);
  }

  Future<void> _openPlaylist(_StorePlaylistData playlist) async {
    final tracks = _tracksForPlaylist(playlist);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(playlist.name),
        content: SizedBox(
          width: 440,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tracks.length} tracks · ${playlist.isSmart ? 'Smart playlist' : 'Your playlist'}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(child: Text('Playlist tracks are not loaded in this profile yet.'))
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return ListTile(
                            leading: const Icon(Icons.music_note_rounded),
                            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${track.artist} · ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MusicScreen()),
              );
            },
            icon: const Icon(Icons.library_music_rounded),
            label: const Text('Open Music'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    if (design == null) {
      return const Scaffold(
        body: Center(child: Text('Create a Virtual Store design in Customize App first.')),
      );
    }

    final posters = _ownedLibrary;
    final physicalCollections = CollectionRepository().fromLibrary();
    final zoneLabels = _zoneLabels;
    final selectedZone = zoneLabels.isEmpty ? 'Entrance' : zoneLabels[_safeZoneIndex];

    return Scaffold(
      backgroundColor: Color(design.wallColor),
      appBar: AppBar(
        backgroundColor: Color(design.shelfColor),
        title: Text(design.name),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.verified_rounded, size: 15),
              label: Text('OWNED LIBRARY'),
            ),
          ),
          IconButton(
            tooltip: 'Keyboard controls',
            onPressed: _showControls,
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
        ],
      ),
      body: Focus(
        focusNode: _navigationFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _navigationFocus.requestFocus(),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
            children: [
              _StoreInteriorWall(
                design: design,
                posterMedia: posters,
              ),
              if (design.collectionGalleryPlacement == 'Front display') ...[
                const SizedBox(height: 16),
                _buildPhysicalCollections(physicalCollections, design),
              ],
              const SizedBox(height: 12),
              _buildWalkway(design, zoneLabels, selectedZone),
              const SizedBox(height: 10),
              _buildNavigationPanel(design, zoneLabels),
              const SizedBox(height: 16),
              _buildCurrentZonePanel(design),
              const SizedBox(height: 22),
              _buildCuratedCollections(design),
              if (design.collectionGalleryPlacement == 'Center island') ...[
                const SizedBox(height: 22),
                _buildPhysicalCollections(physicalCollections, design),
              ],
              const SizedBox(height: 22),
              _buildListeningLounge(design),
              if (design.collectionGalleryPlacement == 'Back wall') ...[
                const SizedBox(height: 22),
                _buildPhysicalCollections(physicalCollections, design),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalkway(
    VirtualStoreDesign design,
    List<String> zones,
    String selectedZone,
  ) {
    final maxIndex = (zones.length - 1).clamp(1, 1000).toDouble();
    final alignmentX = -1.0 + (_safeZoneIndex / maxIndex) * 2.0;
    return Container(
      height: 178,
      decoration: BoxDecoration(
        color: Color(design.floorColor),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(design.accentColor).withValues(alpha: .65)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 7)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(design.wallColor),
                    Color(design.floorColor),
                    Colors.black.withValues(alpha: .72),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: Container(height: 2, color: Color(design.accentColor).withValues(alpha: .45)),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: Text(
              design.navigationMode == 'firstPerson'
                  ? 'FIRST-PERSON WALKWAY'
                  : design.navigationMode == 'easyBrowse'
                      ? 'EASY BROWSE MAP'
                      : 'STORE WALKWAY · THIRD PERSON',
              style: const TextStyle(fontSize: 9, letterSpacing: 1.4, color: Colors.white60, fontWeight: FontWeight.w900),
            ),
          ),
          if (design.navigationMode == 'thirdPerson')
            AnimatedAlign(
              alignment: Alignment(alignmentX, .28),
              duration: _motionDuration,
              curve: Curves.easeInOutCubic,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(design.accentColor),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(design.accentColor).withValues(alpha: .38), blurRadius: 14)],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.black, size: 30),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(99)),
                      child: const Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            )
          else if (design.navigationMode == 'firstPerson')
            Center(
              child: AnimatedScale(
                duration: _motionDuration,
                scale: 1 + (_safeZoneIndex % 3) * .025,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 44, color: Color(design.accentColor)),
                    const SizedBox(height: 4),
                    const Text('YOUR VIEW', style: TextStyle(fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            )
          else
            Center(
              child: Icon(Icons.explore_rounded, size: 46, color: Color(design.accentColor)),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 7,
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 13, color: Colors.white70),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'You are at: $selectedZone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${_safeZoneIndex + 1}/${zones.length}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel(VirtualStoreDesign design, List<String> zones) {
    return Card(
      color: Color(design.shelfColor).withValues(alpha: .88),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_rounded),
                const SizedBox(width: 8),
                const Expanded(child: Text('Walk through the store', style: TextStyle(fontWeight: FontWeight.w900))),
                TextButton(
                  onPressed: _showControls,
                  child: const Text('Controls'),
                ),
              ],
            ),
            Text(
              design.navigationMode == 'easyBrowse'
                  ? 'Tap a zone to browse. No walking controls required.'
                  : 'Use W/A/S/D or the arrow keys to move between zones. Press E / Enter to interact.',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < zones.length; index++)
                  ChoiceChip(
                    label: Text(zones[index]),
                    selected: index == _safeZoneIndex,
                    onSelected: (_) => setState(() {
                      _zoneIndex = index;
                      _shelfOpen = false;
                      _selectedMediaIndex = 0;
                      _selectedMediaId = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dPadButton(Icons.keyboard_arrow_left_rounded, 'Previous zone', () => _shelfOpen ? _cycleMedia(-1) : _selectZone(-1)),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _dPadButton(Icons.keyboard_arrow_up_rounded, 'Previous item / zone', () => _shelfOpen ? _cycleMedia(-1) : _selectZone(-1)),
                    const SizedBox(height: 4),
                    _dPadButton(Icons.keyboard_arrow_down_rounded, 'Next item / zone', () => _shelfOpen ? _cycleMedia(1) : _selectZone(1)),
                  ],
                ),
                const SizedBox(width: 8),
                _dPadButton(Icons.keyboard_arrow_right_rounded, 'Next zone', () => _shelfOpen ? _cycleMedia(1) : _selectZone(1)),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _shelfOpen ? _inspectSelectedMedia : _openCurrentZone,
                  icon: Icon(_shelfOpen ? Icons.open_in_full_rounded : Icons.touch_app_rounded),
                  label: Text(_shelfOpen ? 'Inspect selected' : 'E · Interact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dPadButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 42,
        height: 38,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: () {
            onPressed();
            _navigationFocus.requestFocus();
          },
          icon: Icon(icon),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _buildCurrentZonePanel(VirtualStoreDesign design) {
    final aisle = _currentAisle;
    final aisleCount = design.aisles.length;
    if (_safeZoneIndex == aisleCount) {
      return _buildCollectionsJumpPanel(design);
    }
    if (_safeZoneIndex > aisleCount) {
      return _buildPlaylistsJumpPanel(design);
    }
    if (aisle == null) return const SizedBox.shrink();

    final shelves = _shelvesFor(aisle);
    final allItems = _currentAisleItems;
    final selected = _selectedMedia;
    return Card(
      color: Color(design.shelfColor).withValues(alpha: .75),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 7, height: 26, decoration: BoxDecoration(color: Color(aisle.color), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(aisle.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(design.accentColor))),
                ),
                if (_shelfOpen)
                  IconButton(
                    tooltip: 'Return to walkway',
                    onPressed: () => setState(() => _shelfOpen = false),
                    icon: const Icon(Icons.close_fullscreen_rounded),
                  ),
              ],
            ),
            if (aisle.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(aisle.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            if (!_shelfOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.video_library_rounded, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${allItems.length} owned titles on these shelves. Press E / Enter or tap Browse aisle to step closer.', style: const TextStyle(fontSize: 12, color: Colors.white70))),
                    FilledButton(onPressed: _openCurrentZone, child: const Text('Browse aisle')),
                  ],
                ),
              )
            else ...[
              for (var shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++)
                _buildShelf(design, shelves[shelfIndex], shelfIndex, allItems),
              if (selected != null)
                Card(
                  color: Color(design.accentColor).withValues(alpha: .13),
                  child: ListTile(
                    leading: SizedBox(width: 42, child: CatalogPosterImage(media: selected, fit: BoxFit.cover)),
                    title: Text(selected.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${selected.type} · ${MediaCaseStyle.canonicalFormat(selected.displayCaseFormat)}'),
                    trailing: FilledButton.icon(
                      onPressed: _inspectSelectedMedia,
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: const Text('Inspect'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShelf(
    VirtualStoreDesign design,
    _StoreShelfData shelf,
    int shelfIndex,
    List<MediaItem> allItems,
  ) {
    if (shelf.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text('${shelf.title}: no matching owned media yet.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 7),
          child: Row(
            children: [
              const Icon(Icons.video_library_rounded, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text(shelf.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('${shelf.items.length} titles', style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),
        SizedBox(
          height: 204,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final media = shelf.items[index];
              final selectedIndex = allItems.indexWhere((item) => item.id == media.id);
              final isSelected = media.id == _selectedMediaId ||
                  (_selectedMediaId == null && selectedIndex == _selectedMediaIndex);
              final isPhysical = MediaCaseStyle.canonicalFormat(media.displayCaseFormat) != 'Digital / not recorded';
              return SizedBox(
                width: 116,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMediaIndex = selectedIndex < 0 ? 0 : selectedIndex;
                      _selectedMediaId = media.id;
                    });
                    _navigationFocus.requestFocus();
                  },
                  onDoubleTap: () {
                    setState(() {
                      _selectedMediaIndex = selectedIndex < 0 ? 0 : selectedIndex;
                      _selectedMediaId = media.id;
                    });
                    if (isPhysical) {
                      showAnimatedMediaCaseDialog(
                        context,
                        media: media,
                        animationLevel: design.animationLevel,
                        onOpenTitle: () => _openMediaDetails(media),
                      );
                    } else {
                      _openMediaDetails(media);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: _motionDuration,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(design.accentColor).withValues(alpha: .22) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Color(design.accentColor) : Colors.white12, width: isSelected ? 2 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: Color(design.accentColor).withValues(alpha: .22), blurRadius: 12)] : const [],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedScale(
                            duration: _motionDuration,
                            scale: isSelected ? 1.04 : 1,
                            child: isPhysical
                                ? MediaCase3DView(title: media.title, media: media, width: 100, height: 142)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CatalogPosterImage(media: media, width: 102, height: 142, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsJumpPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .8),
        child: ListTile(
          leading: const Icon(Icons.collections_bookmark_rounded, size: 32),
          title: const Text('Collection Gallery', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('Physical box sets and curated digital collections · ${design.collectionGalleryPlacement}'),
          trailing: const Icon(Icons.arrow_downward_rounded),
          onTap: () {
            final target = _collectionsKey.currentContext;
            if (target != null) Scrollable.ensureVisible(target, duration: _motionDuration);
          },
        ),
      );

  Widget _buildPlaylistsJumpPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .8),
        child: ListTile(
          leading: const Icon(Icons.queue_music_rounded, size: 32),
          title: const Text('Listening Lounge', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('Playlists are virtual music collections, not physical disc cases.'),
          trailing: const Icon(Icons.arrow_downward_rounded),
          onTap: () {
            final target = _playlistsKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(target, duration: _motionDuration);
            }
          },
        ),
      );

  Widget _buildCuratedCollections(VirtualStoreDesign design) {
    final collections = design.curatedCollections;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'Curated digital collections',
            subtitle: 'Your own themed groups of owned titles. They stay digital and do not pretend to be physical box sets.',
            icon: Icons.collections_bookmark_rounded,
            accent: Color(design.accentColor),
          ),
          if (collections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Create themed groups in Customize App → Virtual Store → Digital collections.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            )
          else
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: collections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  final items = _ownedLibrary.where((media) => collection.mediaIds.contains(media.id)).toList(growable: false);
                  return SizedBox(
                    width: 220,
                    child: Card(
                      color: Color(design.shelfColor),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openDigitalCollection(collection),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              height: double.infinity,
                              child: collection.artworkUrl.trim().isNotEmpty
                                  ? Image.network(collection.artworkUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.collections_bookmark_rounded, size: 36))
                                  : items.isNotEmpty
                                      ? CatalogPosterImage(media: items.first, fit: BoxFit.cover)
                                      : const Icon(Icons.collections_bookmark_rounded, size: 36),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DIGITAL COLLECTION', style: TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white60, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 5),
                                    Text(collection.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text('${items.length} titles', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
  }

  Widget _buildPhysicalCollections(List<MediaCollection> physicalCollections, VirtualStoreDesign design) {
    return Container(
      key: _collectionsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _StoreSectionHeading(
          title: 'Physical box-set gallery',
          subtitle: 'Placed at ${design.collectionGalleryPlacement.toLowerCase()}. Open a physical box to reveal its indexed discs and programs.',
          icon: Icons.inventory_2_rounded,
          accent: Color(design.accentColor),
        ),
        if (physicalCollections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Physical collections appear here when owned titles share a physical release or collection ID.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          )
        else
          Column(
            children: [
              for (final collection in physicalCollections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CollectionBox(
                    collection: collection,
                    onTap: () => _openPhysicalCollection(collection),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListeningLounge(VirtualStoreDesign design) {
    final playlists = _playlists;
    final allTracks = <MusicTrack>{..._music.tracks, ..._music.catalogTracks.values};
    return Container(
      key: _playlistsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'Music listening lounge',
            subtitle: 'Playlists are arranged like listening cards and album sleeves—not as physical CDs unless an owned physical CD edition exists.',
            icon: Icons.headphones_rounded,
            accent: Color(design.accentColor),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Your custom and smart playlists will appear here after they are created in Music.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final tracks = playlist.trackIds
                      .map((id) => allTracks.where((track) => track.id == id).isEmpty
                          ? null
                          : allTracks.firstWhere((track) => track.id == id))
                      .whereType<MusicTrack>()
                      .toList(growable: false);
                  final artworkTracks = tracks.where((track) => track.artworkUrl?.trim().isNotEmpty == true);
                  final artwork = artworkTracks.isEmpty ? null : artworkTracks.first.artworkUrl;
                  return SizedBox(
                    width: 154,
                    child: InkWell(
                      onTap: () => _openPlaylist(playlist),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        color: Color(design.shelfColor),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (artwork != null)
                                    Image.network(artwork, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF283040), child: Icon(Icons.queue_music_rounded, size: 42)))
                                  else
                                    const ColoredBox(color: Color(0xFF283040), child: Icon(Icons.queue_music_rounded, size: 42)),
                                  Positioned(
                                    left: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(99)),
                                      child: Text(playlist.isSmart ? 'SMART MIX' : 'PLAYLIST', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${tracks.length} tracks', style: const TextStyle(color: Colors.white70, fontSize: 9)),
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
            ),
        ],
      ),
    );
  }

  void _showControls() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Virtual Store controls'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('W / ↑  ·  Move to previous zone'),
            Text('S / ↓  ·  Move to next zone'),
            Text('A / ←  ·  Move left / previous item'),
            Text('D / →  ·  Move right / next item'),
            Text('E / Enter  ·  Interact with aisle or inspect selected case'),
            Text('Esc  ·  Close the shelf view'),
            SizedBox(height: 10),
            Text('Mouse / touch: tap a zone, tap a case to select it, then use Inspect. Double-tap a case to open it.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _StoreInteriorWall extends StatelessWidget {
  const _StoreInteriorWall({required this.design, required this.posterMedia});

  final VirtualStoreDesign design;
  final List<MediaItem> posterMedia;

  MediaItem? _mediaForPoster(Map<String, dynamic> poster, int fallbackIndex) {
    final requestedId = poster['mediaId']?.toString();
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final media in posterMedia) {
        if (media.id == requestedId) return media;
      }
    }
    return fallbackIndex < posterMedia.length ? posterMedia[fallbackIndex] : null;
  }

  @override
  Widget build(BuildContext context) {
    final configuredPosters = design.showWallPosters
        ? design.layoutElements
            .where((item) => item['type']?.toString() == 'poster' || item['type']?.toString() == 'standee')
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final posters = configuredPosters.isNotEmpty
        ? configuredPosters
        : (design.showWallPosters
            ? posterMedia.take(5).map((media) => <String, dynamic>{
                'label': media.title,
                'mediaId': media.id,
                'placement': 'Around the store',
              }).toList(growable: false)
            : <Map<String, dynamic>>[]);
    final posterGroups = <String, List<Map<String, dynamic>>>{};
    for (final poster in posters) {
      final location = poster['placement']?.toString().trim();
      final label = location == null || location.isEmpty ? 'Around the store' : location;
      (posterGroups[label] ??= <Map<String, dynamic>>[]).add(poster);
    }

    final banners = design.showHangingBanners
        ? design.layoutElements.where((item) => item['type']?.toString() == 'hangingBanner').toList(growable: false)
        : <Map<String, dynamic>>[];
    final bannerItems = banners.isEmpty && design.showHangingBanners
        ? const <Map<String, dynamic>>[
            {'label': 'MOVIES & FILMS', 'placement': 'Overhead · front aisle'},
            {'label': 'TV SHOWS & SPECIALS', 'placement': 'Overhead · center aisle'},
            {'label': 'MUSIC & ALBUMS', 'placement': 'Overhead · music aisle'},
          ]
        : banners;

    return Container(
      decoration: BoxDecoration(
        color: Color(design.wallColor),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(design.accentColor).withValues(alpha: .6)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(design.shelfColor), Color(design.wallColor)]),
            ),
            child: Column(
              children: [
                if (design.logoUrl.trim().isNotEmpty)
                  Image.network(design.logoUrl, height: 36, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                Text(design.name.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: Color(design.accentColor), fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(design.greeting, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          if (bannerItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(design.wallColor), Color(design.shelfColor).withValues(alpha: .8)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 7),
                    child: Text('HANGING AISLE SIGNS', style: TextStyle(fontSize: 8, letterSpacing: 1.4, color: Colors.white60, fontWeight: FontWeight.w900)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final banner in bannerItems)
                        SizedBox(
                          width: 104,
                          child: Column(
                            children: [
                              Transform(
                                alignment: Alignment.topCenter,
                                transform: Matrix4.identity()..setEntry(3, 2, .001)..rotateX(-.05),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Color(design.accentColor),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                                  ),
                                  child: Text(banner['label']?.toString().toUpperCase() ?? 'IN YOUR COLLECTION', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(banner['placement']?.toString().toUpperCase() ?? 'OVERHEAD AISLE', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 6, color: Colors.white54, letterSpacing: .6)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (design.showWallPosters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(design.wallColor), Color(design.shelfColor).withValues(alpha: .72), Color(design.wallColor)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 7),
                    child: Text('FRAMED POSTERS & STANDEES AROUND THE STORE', style: TextStyle(fontSize: 8, letterSpacing: 1.2, color: Colors.white60, fontWeight: FontWeight.w900)),
                  ),
                  if (posterGroups.isEmpty)
                    const Text('Add owned-media posters in Customize App → Virtual Store → Store displays.', style: TextStyle(fontSize: 11, color: Colors.white60))
                  else
                    for (final group in posterGroups.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.key.toUpperCase(), style: TextStyle(fontSize: 7, letterSpacing: 1.1, color: Color(design.accentColor), fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var index = 0; index < group.value.length; index++)
                                    SizedBox(
                                      width: 82,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _FramedStorePoster(
                                          media: _mediaForPoster(group.value[index], index),
                                          label: group.value[index]['label']?.toString() ?? 'From your collection',
                                          location: group.value[index]['placement']?.toString() ?? 'Store wall',
                                          accent: Color(design.accentColor),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          if (design.layoutElements.any((item) => item['type']?.toString() == 'neonSign' || item['type']?.toString() == 'decoration'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final element in design.layoutElements.where((item) => item['type']?.toString() == 'neonSign' || item['type']?.toString() == 'decoration'))
                    Chip(avatar: const Icon(Icons.auto_awesome_rounded, size: 14), label: Text(element['label']?.toString() ?? 'Store display')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FramedStorePoster extends StatelessWidget {
  const _FramedStorePoster({
    this.media,
    required this.label,
    required this.location,
    required this.accent,
  });

  final MediaItem? media;
  final String label;
  final String location;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: .68,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D0F),
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 8,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media != null)
                      CatalogPosterImage(media: media!, fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: const Color(0xFF252A35),
                        child: Icon(Icons.local_movies_rounded, color: accent, size: 28),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        color: Colors.black.withValues(alpha: .78),
                        child: Text(
                          media?.title ?? label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 7,
              letterSpacing: .8,
              color: Colors.white60,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _StoreSectionHeading extends StatelessWidget {
  const _StoreSectionHeading({required this.title, required this.subtitle, required this.icon, required this.accent});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StoreShelfData {
  const _StoreShelfData({required this.title, required this.items});
  final String title;
  final List<MediaItem> items;
}

class _StorePlaylistData {
  const _StorePlaylistData({required this.name, required this.trackIds, required this.isSmart});
  final String name;
  final List<String> trackIds;
  final bool isSmart;
}
