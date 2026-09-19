// FILE: `lib/collection_details.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains application logic, UI, or API coordination.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'player.dart';
import 'localization.dart';
import 'music.dart';
import 'shop.dart';

/// Full-screen collection details view. It uses the same profile Details
/// customization as movies and series, while adapting the content sections
/// to a collection.
class CollectionDetailsScreen extends StatefulWidget {
  final MediaCollection collection;

  const CollectionDetailsScreen({super.key, required this.collection});

  @override
  State<CollectionDetailsScreen> createState() => _CollectionDetailsScreenState();
}

/// Implements the `_CollectionDetailsScreenState` class for this feature or UI component.
class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  int _selectedItem = 0;

  MediaCollection get collection => widget.collection;

  DetailsCustomization get customization =>
      DetailsCustomizationStore.settingsFor(AppController.instance.currentProfile);

  CollectionPreferences get preferences =>
      AppController.instance.currentCollectionPreferences;

  List<MediaItem> get items {
    final controller = AppController.instance;
    final result = <MediaItem>[];
    for (final id in collection.mediaIds) {
      for (final media in controller.library) {
        if (media.id == id) {
          result.add(media);
          break;
        }
      }
    }
    return _sortItems(result);
  }

  List<MediaItem> _sortItems(List<MediaItem> source) {
    final result = List<MediaItem>.from(source);
    switch (preferences.itemSort) {
      case 'Title':
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Newest first':
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'Oldest first':
        result.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case 'Collection order':
      default:
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppController.instance,
          builder: (_, __) => CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF090909),
                surfaceTintColor: Colors.transparent,
                title: Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SliverToBoxAdapter(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final sections = <String>[...customization.sectionOrder];
    if (!sections.contains('Collection Items')) {
      sections.add('Collection Items');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections) _section(section),
          if (collection.isCombinedPlaylistCollection) _buildCombinedMusic(),
          if (ShopCatalog.instance.productsForAssociation('collection', collection.id, name: collection.name).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ContextualShopButton.forCollection(collection),
            ),
        ],
      ),
    );
  }

  /// Shows the music side of a combined playlist/collection.
  Widget _buildCombinedMusic() {
    final store = MusicLibraryStore.instance;
    final tracks = collection.musicTrackIds
        .map((id) => store.tracks.where((track) => track.id == id).isEmpty ? null : store.tracks.where((track) => track.id == id).first)
        .whereType<MusicTrack>()
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Combined Playlist', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${tracks.length} song(s) included with ${items.length} media title(s).'),
              const SizedBox(height: 10),
              if (tracks.isEmpty) const UniversalText('The playlist tracks are not currently loaded.'),
              for (final track in tracks)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_rounded),
                  title: Text(track.title),
                  subtitle: Text('${track.artist} • ${track.album}'),
                  trailing: IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => MusicPlaybackController.instance.play(track),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String section) {
    switch (section) {
      case 'Poster':
        return customization.showPoster ? _buildHeroArtwork() : const SizedBox.shrink();
      case 'Title':
        return customization.showTitle ? _buildTitle() : const SizedBox.shrink();
      case 'Metadata':
        return customization.showMetadata ? _buildMetadata() : const SizedBox.shrink();
      case 'Ownership':
        return customization.showOwnership ? _buildOwnership() : const SizedBox.shrink();
      case 'Description':
        return customization.showDescription ? _buildDescription() : const SizedBox.shrink();
      case 'Play':
        return customization.showPlay ? _buildPlay() : const SizedBox.shrink();
      case 'Collection Items':
        return _buildItems();
      case 'Information':
        return customization.showInformation ? _buildInformation() : const SizedBox.shrink();
      case 'Library':
        return customization.showLibrary ? _buildLibrary() : const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeroArtwork() {
    final media = items;
    final urls = media.map((m) => m.imageUrl).whereType<String>().where((u) => u.isNotEmpty).take(4).toList();
    final height = customization.posterStyle == 'Full Screen'
        ? MediaQuery.sizeOf(context).height * .50
        : customization.posterStyle == 'Compact'
            ? 220.0
            : 310.0;

    if (urls.isEmpty) {
      return _artworkFrame(height, const Icon(Icons.collections_bookmark_rounded, size: 72, color: Colors.white38));
    }

    if (customization.posterStyle == 'Side') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 190, height: 255, child: _image(urls.first)),
            const SizedBox(width: 18),
            Expanded(child: _heroSummary()),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (urls.length == 1)
                _image(urls.first)
              else
                Row(children: [for (final url in urls) Expanded(child: _image(url))]),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .05), Colors.black.withValues(alpha: .88)],
                  ),
                ),
              ),
              if (customization.posterStyle == 'Full Screen')
                Positioned(left: 22, right: 22, bottom: 20, child: _heroSummary()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroSummary() {
    return Column(
      crossAxisAlignment: _crossAxisAlignment(),
      children: [
        Text(collection.name, textAlign: _textAlignment(), maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.05)),
        const SizedBox(height: 8),
        UniversalText('${items.length} titles • ${collection.isAutomatic ? 'automatic' : collection.isShared ? 'collaborative' : 'private'}',
            textAlign: _textAlignment(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTitle() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(collection.name, textAlign: _textAlignment(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      );

  Widget _buildMetadata() => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Wrap(alignment: _wrapAlignment(), spacing: 8, runSpacing: 8, children: [
          _pill(Icons.collections_bookmark_outlined, '${items.length} titles'),
          if (collection.isAutomatic) _pill(Icons.auto_awesome_outlined, 'Automatic'),
          if (collection.isShared) _pill(Icons.groups_outlined, 'Shared') else _pill(Icons.lock_outline, 'Private'),
          _pill(Icons.sort_rounded, preferences.itemSort),
        ]),
      );

  Widget _buildOwnership() => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Card(
          child: ListTile(
            leading: Icon(collection.isAutomatic ? Icons.auto_awesome : Icons.check_circle_outline),
            title: Text(collection.isAutomatic ? 'System collection' : 'Profile collection'),
            subtitle: Text(collection.isAutomatic ? 'Maintained automatically.' : 'Managed by the collection owner and contributors.'),
          ),
        ),
      );

  Widget _buildDescription() {
    if (collection.description.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Text(collection.description, textAlign: _textAlignment(), style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.55)),
    );
  }

  Widget _buildPlay() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Align(
          alignment: _buttonAlignment(),
          child: FilledButton.icon(
            onPressed: items.isEmpty ? null : _playSelected,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(collection.autoPlayEnabled ? 'Play Collection' : 'Play'),
          ),
        ),
      );

  Widget _buildItems() {
    final media = items;
    if (media.isEmpty) {
      return const Padding(padding: EdgeInsets.only(bottom: 24), child: Card(child: Padding(padding: EdgeInsets.all(20), child: UniversalText('This collection has no available titles on your server.'))));
    }

    final title = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UniversalText('Collection Items', textAlign: _textAlignment(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    );

    if (preferences.itemLayout == 'List') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(children: [title, for (var i = 0; i < media.length; i++) _itemListCard(media[i], i)]),
      );
    }

    final columns = MediaQuery.sizeOf(context).width >= 1000 ? 4 : MediaQuery.sizeOf(context).width >= 650 ? 3 : 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(children: [
        title,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: media.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: .62, crossAxisSpacing: 12, mainAxisSpacing: 14),
          itemBuilder: (_, i) => _itemGridCard(media[i], i),
        ),
      ]),
    );
  }

  Widget _itemGridCard(MediaItem media, int index) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _image(media.imageUrl)),
            Padding(padding: const EdgeInsets.fromLTRB(10, 9, 10, 2), child: UniversalText('${index + 1}. ${media.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 9), child: UniversalText('${media.releaseYear ?? ''} • ${media.type}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
          ]),
        ),
      );

  Widget _itemListCard(MediaItem media, int index) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: SizedBox(width: 52, height: 68, child: _image(media.imageUrl)),
          title: UniversalText('${index + 1}. ${media.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: UniversalText('${media.releaseYear ?? ''} • ${media.type}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
        ),
      );

  Widget _buildInformation() => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          UniversalText('Information', textAlign: _textAlignment(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _info('Items', '${items.length}'),
          _info('Sort', preferences.itemSort),
          _info('Playback preference', collection.autoPlayVersionPreference),
          _info('Next item', collection.autoPlayNextTiming),
        ]))),
      );

  Widget _buildLibrary() => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: OutlinedButton.icon(
          onPressed: collection.isAutomatic ? null : _showCollectionActions,
          icon: const Icon(Icons.tune_rounded),
          label: const UniversalText('Collection Actions'),
        ),
      );

  void _playSelected() {
    final media = items;
    if (media.isEmpty) return;
    final index = _selectedItem.clamp(0, media.length - 1).toInt();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(media: media[index])));
  }

  void _showCollectionActions() {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, children: [
      ListTile(leading: const Icon(Icons.play_arrow_rounded), title: const UniversalText('Play first item'), onTap: () { Navigator.pop(context); _selectedItem = 0; _playSelected(); }),
      ListTile(leading: const Icon(Icons.edit_outlined), title: const UniversalText('Collection settings'), subtitle: Text(collection.sortMode)),
    ])));
  }

  Widget _image(String? url) {
    if (url == null || url.trim().isEmpty) return Container(color: const Color(0xFF171717), child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white38, size: 40)));
    return Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF171717), child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38))));
  }

  Widget _artworkFrame(double height, Widget child) => Padding(padding: const EdgeInsets.only(bottom: 22), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: height, child: child)));

  Widget _pill(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: Colors.white70), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]));

  Widget _info(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 145, child: Text(label, style: const TextStyle(color: Colors.white54))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]));

  Alignment _buttonAlignment() => switch (customization.buttonAlignment) { 'Center' => Alignment.center, 'Right' => Alignment.centerRight, _ => Alignment.centerLeft };
  TextAlign _textAlignment() => switch (customization.titleAlignment) { 'Center' => TextAlign.center, 'Right' => TextAlign.right, _ => TextAlign.left };
  WrapAlignment _wrapAlignment() => switch (customization.titleAlignment) { 'Center' => WrapAlignment.center, 'Right' => WrapAlignment.end, _ => WrapAlignment.start };
  CrossAxisAlignment _crossAxisAlignment() => switch (customization.titleAlignment) { 'Center' => CrossAxisAlignment.center, 'Right' => CrossAxisAlignment.end, _ => CrossAxisAlignment.start };
}
