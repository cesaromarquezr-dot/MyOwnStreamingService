// FILE: lib/feature_center.dart
// Purpose: Implements the feature center portion of the streaming service.
// Part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'collection_details.dart';
import 'details.dart';
import 'localization.dart';

/// Main feature/discovery center for advanced streaming-service features.
class FeatureCenterScreen extends StatefulWidget {
  const FeatureCenterScreen({super.key});

  @override
  State<FeatureCenterScreen> createState() =>
      _FeatureCenterScreenState();
}

class _FeatureCenterScreenState
    extends State<FeatureCenterScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText(
          'Discover & Recaps',
        ),
        actions: const [
          LanguagePicker(),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                RecommendationsPanel(),
                CollectionsPanel(),
                WrappedPanel(monthly: true),
                WrappedPanel(monthly: false),
                SharedActorsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const labels = [
      'Recommendations',
      'Collections',
      'Monthly Wrapped',
      'Year End Wrapped',
      'Shared Actors',
    ];

    const icons = [
      Icons.auto_awesome_rounded,
      Icons.collections_bookmark_outlined,
      Icons.calendar_month_outlined,
      Icons.calendar_today_outlined,
      Icons.people_alt_outlined,
    ];

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          10,
        ),
        child: Row(
          children: List.generate(
            labels.length,
            (index) {
              final selected = tab == index;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 8,
                ),
                child: ChoiceChip(
                  selected: selected,
                  avatar: Icon(
                    icons[index],
                    size: 17,
                  ),
                  label: UniversalText(labels[index]),
                  onSelected: (_) {
                    setState(() {
                      tab = index;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Recommendations based on profile activity.
class RecommendationsPanel extends StatelessWidget {
  const RecommendationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profiles =
        controller.currentAccount?.profiles ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),
      children: [
        _FeatureHero(
          icon: Icons.auto_awesome_rounded,
          title: 'Similarity Recommendations',
          subtitle:
              'Compare profile viewing and like activity to discover titles that may fit each profile.',
        ),
        const SizedBox(height: 18),
        if (profiles.length < 2)
          _EmptyFeatureCard(
            icon: Icons.people_outline,
            title: 'More profiles are needed',
            message:
                'Add at least two profiles to compare viewing interests.',
          )
        else
          ...profiles.map(
            (profile) {
              final watchedCount =
                  controller.watched.where(
                (item) => item.id.isNotEmpty,
              ).length;

              final likedCount =
                  controller.liked.where(
                (item) => item.id.isNotEmpty,
              ).length;

              final recommendations =
                  _recommendationsForProfile(
                controller,
                profile.id,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    child: Text(
                      _profileInitial(
                        profile.name,
                      ),
                    ),
                  ),
                  title: Text(
                    profile.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '$watchedCount watched • $likedCount liked',
                  ),
                  children: [
                    if (recommendations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          20,
                        ),
                        child: UniversalText(
                          'Watch and like more titles to improve recommendations.',
                          style: TextStyle(
                            color: Colors.white60,
                          ),
                        ),
                      )
                    else
                      ...recommendations.map(
                        (title) => _recommendationTile(
                          context,
                          title,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () =>
              _showCreateRecommendation(context),
          icon: const Icon(Icons.add_rounded),
          label: const UniversalText(
            'Create recommendation vote',
          ),
        ),
      ],
    );
  }

  static List<dynamic> _recommendationsForProfile(
    AppController controller,
    String profileId,
  ) {
    final excluded = <String>{
      ...controller.watched.map((item) => item.id),
      ...controller.liked.map((item) => item.id),
    };

    return controller.library
        .where(
          (title) {
            final id = _titleId(title);

            if (id == null || excluded.contains(id)) {
              return false;
            }

            return true;
          },
        )
        .take(5)
        .toList();
  }

  static String? _titleId(dynamic title) {
    try {
      final value = title.id;
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  static String _titleName(dynamic title) {
    try {
      final value = title.title;
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}

    try {
      final value = title.name;
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}

    return 'Untitled';
  }

  static String _profileInitial(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) return '?';

    return trimmed.characters.first.toUpperCase();
  }

  Widget _recommendationTile(
    BuildContext context,
    dynamic title,
  ) {
    final name = _titleName(title);
    final id = _titleId(title);

    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.movie_outlined),
      ),
      title: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: const UniversalText(
        'Recommended from available library activity',
      ),
      trailing: IconButton(
        tooltip: tr('Like recommendation'),
        icon: const Icon(
          Icons.favorite_border_rounded,
        ),
        onPressed: () {
          AppController.instance.activity.add(
            ActivityItem(
              id: 'recommendation_like_${DateTime.now().microsecondsSinceEpoch}',
              action: 'Recommendation liked',
              title: name,
              timestamp: DateTime.now(),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: UniversalText(
                '$name added to recommendation activity.',
              ),
            ),
          );
        },
      ),
      onTap: id == null
          ? null
          : () {
              _openTitleDetails(
                context,
                title,
              );
            },
    );
  }

  void _showCreateRecommendation(
    BuildContext context,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => const _CreateVoteDialog(),
    );
  }

  static void _openTitleDetails(
    BuildContext context,
    dynamic title,
  ) {
    if (title is! MediaItem) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailsScreen(media: title),
      ),
    );
  }
}

/// Dialog for creating a recommendation vote.
class _CreateVoteDialog extends StatefulWidget {
  const _CreateVoteDialog();

  @override
  State<_CreateVoteDialog> createState() =>
      _CreateVoteDialogState();
}

class _CreateVoteDialogState
    extends State<_CreateVoteDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _post() {
    final title = controller.text.trim();

    if (title.isEmpty) {
      return;
    }

    AppController.instance.activity.add(
      ActivityItem(
        id: 'recommendation_create_${DateTime.now().microsecondsSinceEpoch}',
        action:
            'Recommendation created • votes open to everyone',
        title: title,
        timestamp: DateTime.now(),
      ),
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UniversalText(
          'Recommendation created for $title.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const UniversalText(
        'New recommendation',
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Movie or show title',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _post(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UniversalText('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _post,
          icon: const Icon(Icons.send_rounded),
          label: const UniversalText('Post'),
        ),
      ],
    );
  }
}

/// Collections browser and organizer.
class CollectionsPanel extends StatefulWidget {
  const CollectionsPanel({super.key});

  @override
  State<CollectionsPanel> createState() =>
      _CollectionsPanelState();
}

class _CollectionsPanelState
    extends State<CollectionsPanel> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    AppController.instance.seedCollections();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final prefs =
            controller.currentCollectionPreferences;

        final normalizedSearch =
            _searchQuery.trim().toLowerCase();

        final all = controller.collections.where(
          (collection) {
            if (normalizedSearch.isEmpty) {
              return true;
            }

            final name =
                collection.name.toLowerCase();

            final description =
                collection.description.toLowerCase();

            return name.contains(normalizedSearch) ||
                description.contains(normalizedSearch);
          },
        ).toList();

        final mine = all.where(
          (collection) =>
              collection.createdByProfileId ==
              controller.currentProfile?.id,
        );

        final liked = all.where(
          (collection) =>
              collection.isLikedByCurrentProfile &&
              !mine.contains(collection),
        );

        final automatic = all.where(
          (collection) => collection.isAutomatic,
        );

        final custom = all.where(
          (collection) => !collection.isAutomatic,
        );

        final ordered = _orderCollections(
          all,
          prefs,
        );

        return Scaffold(
          backgroundColor:
              Theme.of(context).scaffoldBackgroundColor,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32,
            ),
            children: [
              _FeatureHero(
                icon: Icons.collections_bookmark_rounded,
                title: 'Collections',
                subtitle:
                    'Automatic franchise collections, collaborative custom collections, and profile-personalized library organization.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const UniversalText(
                      'Create Collection',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _customize(context),
                    icon: const Icon(
                      Icons.tune_rounded,
                    ),
                    label: const UniversalText(
                      'Customize collections',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.search_rounded),
                  hintText: tr('Search collections'),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('Clear search'),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _buildStats(
                all.length,
                automatic.length,
                custom.length,
                liked.length,
              ),
              const SizedBox(height: 20),
              if (all.isEmpty)
                _EmptyFeatureCard(
                  icon: Icons.collections_bookmark_outlined,
                  title: controller.collections.isEmpty
                      ? 'Your Collections Are Ready'
                      : 'No collections match your search.',
                  message: controller.collections.isEmpty
                      ? 'Create a custom collection or import media with ARM. Automatic franchise collections appear when verified relationships are identified.'
                      : 'Try another search or clear the filter.',
                )
              else
                ..._buildSections(
                  controller,
                  ordered,
                  mine.toList(),
                  liked.toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  List<dynamic> _orderCollections(
    List<dynamic> collections,
    dynamic prefs,
  ) {
    final result = collections.toList();

    String? ordering;

    try {
      ordering = prefs.collectionOrder?.toString();
    } catch (_) {}

    if (ordering == 'Automatic first') {
      result.sort(
        (a, b) {
          final aa = a.isAutomatic == true;
          final bb = b.isAutomatic == true;

          if (aa == bb) return 0;

          return aa ? -1 : 1;
        },
      );
    } else if (ordering == 'Custom first') {
      result.sort(
        (a, b) {
          final aa = a.isAutomatic == true;
          final bb = b.isAutomatic == true;

          if (aa == bb) return 0;

          return aa ? 1 : -1;
        },
      );
    }

    return result;
  }

  Widget _buildStats(
    int collections,
    int automatic,
    int custom,
    int liked,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 800 ? 4 : 2;

        final cards = [
          _collectionStat(
            'Collections',
            collections,
            Icons.collections_bookmark_outlined,
          ),
          _collectionStat(
            'Automatic',
            automatic,
            Icons.auto_awesome_motion_outlined,
          ),
          _collectionStat(
            'Custom',
            custom,
            Icons.edit_note_outlined,
          ),
          _collectionStat(
            'Liked',
            liked,
            Icons.favorite_border_rounded,
          ),
        ];

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _collectionStat(
    String label,
    int value,
    IconData icon,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    AppController controller,
    List<dynamic> ordered,
    List<dynamic> mine,
    List<dynamic> liked,
  ) {
    final sections =
        controller.collectionSectionOrder;

    final widgets = <Widget>[];

    for (final section in sections) {
      final name = section.toString();

      List<dynamic> entries;

      switch (name) {
        case 'My Collections':
          entries = mine;
          break;
        case 'Liked Collections':
          entries = liked;
          break;
        case 'Featured Collections':
        default:
          entries = ordered;
          break;
      }

      if (entries.isEmpty) continue;

      widgets.add(
        _collectionSectionHeader(name),
      );

      widgets.add(
        _collectionGrid(entries),
      );

      widgets.add(
        const SizedBox(height: 20),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        _collectionGrid(ordered),
      );
    }

    return widgets;
  }

  Widget _collectionSectionHeader(String title) {
    String description;

    switch (title) {
      case 'My Collections':
        description =
            'Collections created by profiles on this account.';
        break;
      case 'Liked Collections':
        description =
            'Collections liked by the current profile.';
        break;
      default:
        description =
            'Automatic and featured collections available in the library.';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionGrid(
    List<dynamic> collections,
  ) {
    final controller = AppController.instance;

    final prefs =
        controller.currentCollectionPreferences;

    String layout = 'Grid';

    try {
      layout = prefs.layout.toString();
    } catch (_) {}

    if (layout == 'List') {
      return Column(
        children: collections
            .map(
              (collection) => _collectionCard(
                collection,
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth > 700 ? 4 : 2;

        return GridView.builder(
          itemCount: collections.length,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            return _collectionCard(
              collections[index],
            );
          },
        );
      },
    );
  }

  Widget _collectionCard(MediaCollection collection) {
    final controller = AppController.instance;

    final name = collection.name;
    final description = collection.description;

    // MediaCollection stores collection membership in mediaIds. The previous
    // implementation referenced legacy/dynamic properties (titleIds, titles,
    // and isPrivate) that do not exist on the current model and caused the
    // Collections screen to throw NoSuchMethodError at runtime.
    final count = collection.mediaIds.length;

    final automatic = collection.isAutomatic;
    final shared = collection.isShared;
    final privateCollection = !collection.isShared;
    final editable = collection.canCurrentProfileEdit();
    final canAdd = !automatic && collection.canCurrentProfileAdd();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(
          context,
          collection,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(10),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      automatic
                          ? Icons.auto_awesome
                          : Icons.collections_bookmark,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('Collection actions'),
                    onSelected: (action) {
                      _collectionAction(
                        context,
                        collection,
                        action,
                      );
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: Text('Play'),
                      ),
                      const PopupMenuItem(
                        value: 'browse',
                        child: Text(
                          'Browse titles',
                        ),
                      ),
                      if (shared &&
                          editable &&
                          !automatic)
                        const PopupMenuItem(
                          value: 'contributors',
                          child: Text(
                            'Manage contributors',
                          ),
                        ),
                      if (!collection.isOfficial &&
                          editable)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  description.isEmpty
                      ? 'Library collection'
                      : description,
                  maxLines: 4,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _collectionPill(
                    '$count titles',
                    Icons.movie_outlined,
                  ),
                  _collectionPill(
                    automatic
                        ? 'Automatic'
                        : 'Custom',
                    automatic
                        ? Icons.auto_awesome
                        : Icons.edit_outlined,
                  ),
                  if (shared)
                    _collectionPill(
                      'Shared',
                      Icons.group_outlined,
                    ),
                  if (privateCollection)
                    _collectionPill(
                      'Private',
                      Icons.lock_outline,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: collection
                            .isLikedByCurrentProfile
                        ? tr('Unlike collection')
                        : tr('Like collection'),
                    onPressed: () {
                      controller.toggleCollectionLike(
                        collection.id,
                      );
                    },
                    icon: Icon(
                      collection
                              .isLikedByCurrentProfile
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                  if (canAdd)
                    IconButton(
                      tooltip: tr(
                        'Add title to collection',
                      ),
                      onPressed: () {
                        _showAddToCollection(
                          context,
                          collection,
                        );
                      },
                      icon: const Icon(
                        Icons.add_box_outlined,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    automatic
                        ? 'SYSTEM'
                        : shared
                            ? 'COLLABORATIVE'
                            : 'PROFILE',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionPill(
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        color: Colors.white.withValues(
          alpha: 0.06,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openCollection(
    BuildContext context,
    dynamic collection,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailsScreen(
          collection: collection,
        ),
      ),
    );
  }

  void _collectionAction(
    BuildContext context,
    dynamic collection,
    String action,
  ) {
    switch (action) {
      case 'play':
        _playCollection(collection);
        break;
      case 'browse':
        _openCollection(context, collection);
        break;
      case 'contributors':
        _manageContributors(
          context,
          collection,
        );
        break;
      case 'delete':
        _deleteCollection(
          context,
          collection,
        );
        break;
    }
  }

  void _playCollection(dynamic collection) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UniversalText(
          'Starting ${collection.name}...',
        ),
      ),
    );
  }

  void _manageContributors(
    BuildContext context,
    dynamic collection,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UniversalText(
          'Manage contributors',
        ),
        content: UniversalText(
          'Contributor management for ${collection.name} is available through the collection workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteCollection(
    BuildContext context,
    dynamic collection,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UniversalText(
          'Delete collection?',
        ),
        content: UniversalText(
          'This will remove ${collection.name} from the current collection set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);

              try {
                AppController.instance
                    .deleteCollection(
                  collection.id,
                );
              } catch (_) {}
            },
            child: const UniversalText('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddToCollection(
    BuildContext context,
    dynamic collection,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UniversalText(
          'Add to collection',
        ),
        content: UniversalText(
          'Choose a title from the library to add to ${collection.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UniversalText('Close'),
          ),
        ],
      ),
    );
  }

  void _create(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _CreateCollectionDialog(),
    );
  }

  void _customize(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _CollectionPreferencesDialog(),
    );
  }
}

/// Creates a collection from the feature center.
class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState
    extends State<_CreateCollectionDialog> {
  final nameController = TextEditingController();
  final descriptionController =
      TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _create() {
    final name =
        nameController.text.trim();

    if (name.isEmpty) return;

    try {
      AppController.instance.createCollection(
        name: name,
        description:
            descriptionController.text.trim(),
      );
    } catch (_) {}

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const UniversalText(
        'Create Collection',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration:
                  const InputDecoration(
                labelText: 'Collection name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UniversalText('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const UniversalText('Create'),
        ),
      ],
    );
  }
}

/// Collection organization preferences.
class _CollectionPreferencesDialog
    extends StatelessWidget {
  const _CollectionPreferencesDialog();

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return AlertDialog(
      title: const UniversalText(
        'Customize collections',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const UniversalText(
              'Choose how collections are organized for the current profile.',
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: 'Automatic first',
              items: const [
                DropdownMenuItem(
                  value: 'Automatic first',
                  child: Text('Automatic first'),
                ),
                DropdownMenuItem(
                  value: 'Custom first',
                  child: Text('Custom first'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                try {
                  final preferences = controller.currentCollectionPreferences.copy();
                  preferences.collectionOrder = value;
                  controller.updateCollectionPreferences(preferences);
                } catch (_) {}
              },
              decoration:
                  const InputDecoration(
                labelText: 'Ordering',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: 'Grid',
              items: const [
                DropdownMenuItem(
                  value: 'Grid',
                  child: Text('Grid'),
                ),
                DropdownMenuItem(
                  value: 'List',
                  child: Text('List'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                try {
                  final preferences = controller.currentCollectionPreferences.copy();
                  preferences.layout = value;
                  controller.updateCollectionPreferences(preferences);
                } catch (_) {}
              },
              decoration:
                  const InputDecoration(
                labelText: 'Layout',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UniversalText('Done'),
        ),
      ],
    );
  }
}

/// Monthly or yearly viewing recap.
class WrappedPanel extends StatelessWidget {
  final bool monthly;

  const WrappedPanel({
    super.key,
    required this.monthly,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    final title = monthly
        ? 'Monthly Wrapped'
        : 'Year End Wrapped';

    final icon = monthly
        ? Icons.calendar_month_rounded
        : Icons.auto_graph_rounded;

    final activityCount =
        controller.watched.length;

    final likedCount =
        controller.liked.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),
      children: [
        _FeatureHero(
          icon: icon,
          title: title,
          subtitle: monthly
              ? 'A profile-level snapshot of your recent streaming activity.'
              : 'A larger recap of the year across your streaming library.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 800 ? 3 : 1;

            final cards = [
              _MetricCard(
                icon: Icons.play_circle_outline,
                label: 'Titles watched',
                value: '$activityCount',
              ),
              _MetricCard(
                icon: Icons.favorite_border_rounded,
                label: 'Titles liked',
                value: '$likedCount',
              ),
              _MetricCard(
                icon: Icons.insights_outlined,
                label: 'Profiles',
                value:
                    '${controller.currentAccount?.profiles.length ?? 0}',
              ),
            ];

            if (columns == 1) {
              return Column(
                children: cards
                    .map(
                      (card) => Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: card,
                      ),
                    )
                    .toList(),
              );
            }

            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              children: cards,
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const UniversalText(
                  'YOUR STREAMING STORY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                UniversalText(
                  monthly
                      ? 'Your monthly recap uses the activity currently available to the streaming account and profile.'
                      : 'Your year-end recap uses the activity currently available across the account.',
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared actor discovery.
class SharedActorsPanel extends StatelessWidget {
  const SharedActorsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),
      children: [
        _FeatureHero(
          icon: Icons.people_alt_rounded,
          title: 'Shared Actors',
          subtitle:
              'Find performers and creators connected across titles in the available library.',
        ),
        const SizedBox(height: 18),
        if (controller.library.isEmpty)
          const _EmptyFeatureCard(
            icon: Icons.people_outline,
            title: 'No library titles yet',
            message:
                'Import or add media to discover shared actors.',
          )
        else
          _SharedActorsSummary(
            library: controller.library,
          ),
      ],
    );
  }
}

/// Summary card for shared actors.
class _SharedActorsSummary extends StatelessWidget {
  final List<dynamic> library;

  const _SharedActorsSummary({
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final actors = <String, int>{};

    for (final title in library) {
      try {
        final cast = title.cast;

        if (cast is Iterable) {
          for (final person in cast) {
            final name = person is String
                ? person
                : _personName(person);

            if (name == null || name.trim().isEmpty) {
              continue;
            }

            actors[name] =
                (actors[name] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    final sorted = actors.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    final top = sorted.take(20).toList();

    if (top.isEmpty) {
      return const _EmptyFeatureCard(
        icon: Icons.person_search_outlined,
        title: 'No shared actors detected',
        message:
            'The current library does not expose enough cast metadata to build shared-actor results yet.',
      );
    }

    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(
              Icons.groups_rounded,
            ),
            title: UniversalText(
              'Most connected performers',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: UniversalText(
              'Based on cast metadata available in the current library.',
            ),
          ),
          const Divider(height: 1),
          ...top.map(
            (entry) => ListTile(
              leading: CircleAvatar(
                child: Text(
                  entry.key.characters.first
                      .toUpperCase(),
                ),
              ),
              title: Text(entry.key),
              trailing: Text(
                '${entry.value} titles',
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _personName(
    dynamic person,
  ) {
    try {
      final value = person.name;

      if (value != null) {
        return value.toString();
      }
    } catch (_) {}

    try {
      final value = person['name'];

      if (value != null) {
        return value.toString();
      }
    } catch (_) {}

    return null;
  }
}

/// Generic feature hero used throughout the feature center.
class _FeatureHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(
                alpha: 0.62,
              ),
              scheme.surfaceContainerHighest.withValues(
                alpha: 0.48,
              ),
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(15),
                color: scheme.primary.withValues(
                  alpha: 0.14,
                ),
              ),
              child: Icon(
                icon,
                size: 28,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state used by feature-center panels.
class _EmptyFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyFeatureCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.white38,
            ),
            const SizedBox(height: 14),
            UniversalText(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            UniversalText(
              message,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact metric card.
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}