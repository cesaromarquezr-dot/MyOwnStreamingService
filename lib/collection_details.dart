// FILE: `lib/collection_details.dart`.
// Purpose: Part of the documented streaming-service client/backend architecture.
// Media files remain on the appropriate account server; this source contains
// application logic, UI, and collection navigation.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'player.dart';
import 'localization.dart';

/// Full-screen collection details view.
///
/// The screen uses the current AppController collection when available so
/// collection changes are reflected after controller updates. It also uses
/// the same profile-specific DetailsCustomization used by movie/show details.
class CollectionDetailsScreen extends StatefulWidget {
  final MediaCollection collection;

  const CollectionDetailsScreen({
    super.key,
    required this.collection,
  });

  @override
  State<CollectionDetailsScreen> createState() =>
      _CollectionDetailsScreenState();
}

/// Implements the `_CollectionDetailsScreenState` class for this feature or UI component.
class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  int _selectedItem = 0;

  /// Prefer the current controller copy of the collection.
  ///
  /// Navigation can pass an older MediaCollection instance. If the controller
  /// has since updated that collection, the details screen should display the
  /// updated version instead of the original snapshot.
  MediaCollection get collection {
    final controller = AppController.instance;

    for (final item in controller.collections) {
      if (item.id == widget.collection.id) {
        return item;
      }
    }

    return widget.collection;
  }

  DetailsCustomization get customization =>
      DetailsCustomizationStore.settingsFor(
        AppController.instance.currentProfile,
      );

  CollectionPreferences get preferences =>
      AppController.instance.currentCollectionPreferences;

  /// Resolves the collection's media IDs against the current library.
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
        result.sort(
          (a, b) => a.title
              .toLowerCase()
              .compareTo(b.title.toLowerCase()),
        );
        break;

      case 'Newest first':
        result.sort(
          (a, b) => b.addedAt.compareTo(a.addedAt),
        );
        break;

      case 'Oldest first':
        result.sort(
          (a, b) => a.addedAt.compareTo(b.addedAt),
        );
        break;

      case 'Collection order':
      default:
        break;
    }

    return result;
  }

  @override
  void didUpdateWidget(
    covariant CollectionDetailsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.collection.id != widget.collection.id) {
      _selectedItem = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final media = items;

            if (media.isEmpty) {
              _selectedItem = 0;
            } else if (_selectedItem >= media.length) {
              _selectedItem = media.length - 1;
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: const Color(0xFF090909),
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildContent(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    final sections = <String>[
      ...customization.sectionOrder,
    ];

    if (!sections.contains('Collection Items')) {
      sections.add('Collection Items');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        44,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections)
            _section(section),
        ],
      ),
    );
  }

  Widget _section(String section) {
    switch (section) {
      case 'Poster':
        return customization.showPoster
            ? _buildHeroArtwork()
            : const SizedBox.shrink();

      case 'Title':
        return customization.showTitle
            ? _buildTitle()
            : const SizedBox.shrink();

      case 'Metadata':
        return customization.showMetadata
            ? _buildMetadata()
            : const SizedBox.shrink();

      case 'Ownership':
        return customization.showOwnership
            ? _buildOwnership()
            : const SizedBox.shrink();

      case 'Description':
        return customization.showDescription
            ? _buildDescription()
            : const SizedBox.shrink();

      case 'Play':
        return customization.showPlay
            ? _buildPlay()
            : const SizedBox.shrink();

      case 'Collection Items':
        return _buildItems();

      case 'Information':
        return customization.showInformation
            ? _buildInformation()
            : const SizedBox.shrink();

      case 'Library':
        return customization.showLibrary
            ? _buildLibrary()
            : const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeroArtwork() {
    final media = items;

    final urls = media
        .map((m) => m.imageUrl)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .take(4)
        .toList();

    final height = customization.posterStyle == 'Full Screen'
        ? MediaQuery.sizeOf(context).height * .50
        : customization.posterStyle == 'Compact'
            ? 220.0
            : 310.0;

    if (urls.isEmpty) {
      return _artworkFrame(
        height,
        const Icon(
          Icons.collections_bookmark_rounded,
          size: 72,
          color: Colors.white38,
        ),
      );
    }

    if (customization.posterStyle == 'Side') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 190,
              height: 255,
              child: _image(urls.first),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _heroSummary(),
            ),
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
                Row(
                  children: [
                    for (final url in urls)
                      Expanded(
                        child: _image(url),
                      ),
                  ],
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .05),
                      Colors.black.withValues(alpha: .88),
                    ],
                  ),
                ),
              ),
              if (customization.posterStyle == 'Full Screen')
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: _heroSummary(),
                ),
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
        Text(
          collection.name,
          textAlign: _textAlignment(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        UniversalText(
          '${items.length} titles • '
          '${collection.isAutomatic
              ? 'automatic'
              : collection.isShared
                  ? 'collaborative'
                  : 'private'}',
          textAlign: _textAlignment(),
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        collection.name,
        textAlign: _textAlignment(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: _wrapAlignment(),
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(
            Icons.collections_bookmark_outlined,
            '${items.length} titles',
          ),
          if (collection.isAutomatic)
            _pill(
              Icons.auto_awesome_outlined,
              'Automatic',
            ),
          if (collection.isShared)
            _pill(
              Icons.groups_outlined,
              'Shared',
            )
          else
            _pill(
              Icons.lock_outline,
              'Private',
            ),
          _pill(
            Icons.sort_rounded,
            preferences.itemSort,
          ),
        ],
      ),
    );
  }

  Widget _buildOwnership() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: ListTile(
          leading: Icon(
            collection.isAutomatic
                ? Icons.auto_awesome
                : Icons.check_circle_outline,
          ),
          title: Text(
            collection.isAutomatic
                ? 'System collection'
                : 'Profile collection',
          ),
          subtitle: Text(
            collection.isAutomatic
                ? 'Maintained automatically.'
                : 'Managed by the collection owner and contributors.',
          ),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    if (collection.description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Text(
        collection.description,
        textAlign: _textAlignment(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildPlay() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: _buttonAlignment(),
        child: FilledButton.icon(
          onPressed: items.isEmpty
              ? null
              : _playSelected,
          icon: const Icon(
            Icons.play_arrow_rounded,
          ),
          label: Text(
            collection.autoPlayEnabled
                ? 'Play Collection'
                : 'Play',
          ),
        ),
      ),
    );
  }

  Widget _buildItems() {
    final media = items;

    if (media.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: UniversalText(
              'This collection has no available titles on your server.',
            ),
          ),
        ),
      );
    }

    final title = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UniversalText(
        'Collection Items',
        textAlign: _textAlignment(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (preferences.itemLayout == 'List') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            title,
            for (var i = 0; i < media.length; i++)
              _itemListCard(
                media[i],
                i,
              ),
          ],
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;

    final columns = width >= 1000
        ? 4
        : width >= 650
            ? 3
            : 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          title,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: media.length,
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: .62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (_, i) {
              return _itemGridCard(
                media[i],
                i,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _itemGridCard(
    MediaItem media,
    int index,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaDetailsScreen(
                media: media,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _image(
                media.imageUrl,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                9,
                10,
                2,
              ),
              child: UniversalText(
                '${index + 1}. ${media.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                2,
                10,
                9,
              ),
              child: UniversalText(
                '${media.releaseYear ?? ''} • ${media.type}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemListCard(
    MediaItem media,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: SizedBox(
          width: 52,
          height: 68,
          child: _image(
            media.imageUrl,
          ),
        ),
        title: UniversalText(
          '${index + 1}. ${media.title}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: UniversalText(
          '${media.releaseYear ?? ''} • ${media.type}',
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaDetailsScreen(
                media: media,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInformation() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              UniversalText(
                'Information',
                textAlign: _textAlignment(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _info(
                'Items',
                '${items.length}',
              ),
              _info(
                'Sort',
                preferences.itemSort,
              ),
              _info(
                'Playback preference',
                collection.autoPlayVersionPreference,
              ),
              _info(
                'Next item',
                collection.autoPlayNextTiming,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrary() {
    final canManage = !collection.isAutomatic &&
        collection.canCurrentProfileEdit();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: OutlinedButton.icon(
        onPressed: canManage
            ? _showCollectionActions
            : null,
        icon: const Icon(
          Icons.tune_rounded,
        ),
        label: const UniversalText(
          'Collection Actions',
        ),
      ),
    );
  }

  void _playSelected() {
    final media = items;

    if (media.isEmpty) {
      return;
    }

    final index = _selectedItem
        .clamp(
          0,
          media.length - 1,
        )
        .toInt();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media[index],
        ),
      ),
    );
  }

  void _showCollectionActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.play_arrow_rounded,
                ),
                title: const UniversalText(
                  'Play first item',
                ),
                onTap: () {
                  Navigator.pop(context);

                  if (items.isEmpty) {
                    return;
                  }

                  setState(() {
                    _selectedItem = 0;
                  });

                  _playSelected();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                ),
                title: const UniversalText(
                  'Collection settings',
                ),
                subtitle: Text(
                  collection.sortMode,
                ),
              ),
              if (collection.canCurrentProfileAdd())
                ListTile(
                  leading: const Icon(
                    Icons.add_rounded,
                  ),
                  title: const UniversalText(
                    'Add titles',
                  ),
                  subtitle: const UniversalText(
                    'Add a library title to this collection.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddMedia();
                  },
                ),
              if (collection.isShared)
                ListTile(
                  leading: const Icon(
                    Icons.groups_outlined,
                  ),
                  title: const UniversalText(
                    'Manage contributors',
                  ),
                  subtitle: UniversalText(
                    '${collection.contributorProfileIds.length} contributors',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showContributors();
                  },
                ),
              ListTile(
                leading: Icon(
                  collection.isLikedByCurrentProfile
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                title: UniversalText(
                  collection.isLikedByCurrentProfile
                      ? 'Unlike collection'
                      : 'Like collection',
                ),
                onTap: () {
                  Navigator.pop(context);

                  AppController.instance
                      .toggleCollectionLike(
                    collection.id,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMedia() {
    final controller = AppController.instance;

    if (!collection.canCurrentProfileAdd()) {
      return;
    }

    final available = controller.library
        .where(
          (media) =>
              !collection.mediaIds.contains(media.id),
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.sizeOf(sheetContext).height * .75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add to ${collection.name}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    12,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: UniversalText(
                      'Choose a title from your library.',
                    ),
                  ),
                ),
                Expanded(
                  child: available.isEmpty
                      ? const Center(
                          child: UniversalText(
                            'No additional library titles are available.',
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            20,
                          ),
                          itemCount: available.length,
                          itemBuilder: (_, index) {
                            final media =
                                available[index];

                            return Card(
                              child: ListTile(
                                leading: SizedBox(
                                  width: 48,
                                  height: 62,
                                  child: _image(
                                    media.imageUrl,
                                  ),
                                ),
                                title: Text(
                                  media.title,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${media.releaseYear ?? ''} • ${media.type}',
                                ),
                                trailing: const Icon(
                                  Icons.add_rounded,
                                ),
                                onTap: () {
                                  controller
                                      .addToCollection(
                                    collection.id,
                                    media.id,
                                  );

                                  Navigator.pop(
                                    sheetContext,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showContributors() {
    final controller = AppController.instance;

    if (!collection.canCurrentProfileEdit()) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const UniversalText(
            'Collection contributors',
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UniversalText(
                  'Shared collections can be built together. '
                  'Select profiles allowed to add and manage titles.',
                ),
                const SizedBox(height: 12),
                for (final profile
                    in controller.currentAccount?.profiles ??
                        <Profile>[])
                  CheckboxListTile(
                    value: collection
                        .contributorProfileIds
                        .contains(profile.id),
                    title: Text(
                      profile.name,
                    ),
                    onChanged:
                        profile.id ==
                                collection.createdByProfileId
                            ? null
                            : (value) {
                                setState(() {
                                  if (value == true) {
                                    collection
                                        .contributorProfileIds
                                        .add(profile.id);
                                  } else {
                                    collection
                                        .contributorProfileIds
                                        .remove(profile.id);
                                  }
                                });
                              },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const UniversalText(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _image(String? url) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        color: const Color(0xFF171717),
        child: const Center(
          child: Icon(
            Icons.movie_outlined,
            color: Colors.white38,
            size: 40,
          ),
        ),
      );
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFF171717),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
            ),
          ),
        );
      },
    );
  }

  Widget _artworkFrame(
    double height,
    Widget child,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: child,
        ),
      ),
    );
  }

  Widget _pill(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Alignment _buttonAlignment() {
    switch (customization.buttonAlignment) {
      case 'Center':
        return Alignment.center;
      case 'Right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _textAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return TextAlign.center;
      case 'Right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  WrapAlignment _wrapAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return WrapAlignment.center;
      case 'Right':
        return WrapAlignment.end;
      default:
        return WrapAlignment.start;
    }
  }

  CrossAxisAlignment _crossAxisAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return CrossAxisAlignment.center;
      case 'Right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }
}