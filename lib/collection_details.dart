// FILE: `lib/feature_center.dart`.
// Purpose: Implements the feature center portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

class AppLanguage {
  final String code;
  final String flag;
  final String label;

  const AppLanguage(
    this.code,
    this.flag,
    this.label,
  );
}

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final instance = LanguageController._();

  AppLanguage current =
      const AppLanguage('en', '🇬🇧', 'Eng');

  static const languages = <AppLanguage>[
    AppLanguage('en', '🇬🇧', 'Eng'),
    AppLanguage('es', '🇪🇸', 'Esp'),
    AppLanguage('fr', '🇫🇷', 'Fra'),
    AppLanguage('pt', '🇵🇹', 'Por'),
    AppLanguage('de', '🇩🇪', 'Deu'),
    AppLanguage('it', '🇮🇹', 'Ita'),
    AppLanguage('ja', '🇯🇵', 'Jpn'),
    AppLanguage('ko', '🇰🇷', 'Kor'),
    AppLanguage('zh', '🇨🇳', '中'),
  ];

  void set(AppLanguage value) {
    current = value;
    notifyListeners();
  }
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) {
        final language =
            LanguageController.instance.current;

        return PopupMenuButton<AppLanguage>(
          tooltip: 'Language',
          initialValue: language,
          onSelected:
              LanguageController.instance.set,
          itemBuilder: (_) {
            return [
              for (final l
                  in LanguageController.languages)
                PopupMenuItem<AppLanguage>(
                  value: l,
                  child: Text(
                    '${l.flag}  ${l.label}',
                  ),
                ),
            ];
          },
          child: Container(
            margin: const EdgeInsets.only(
              right: 10,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: .07,
              ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Text(
              '${language.flag} ${language.label}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppText {
  static String get(String key) {
    final language =
        LanguageController.instance.current.code;

    const data = {
      'recommendations': {
        'en': 'Recommendations',
        'es': 'Recomendaciones',
        'fr': 'Recommandations',
        'pt': 'Recomendações',
      },
      'collections': {
        'en': 'Collections',
        'es': 'Colecciones',
        'fr': 'Collections',
        'pt': 'Coleções',
      },
      'monthly': {
        'en': 'Monthly Wrapped',
        'es': 'Resumen mensual',
        'fr': 'Bilan mensuel',
        'pt': 'Resumo mensal',
      },
      'yearly': {
        'en': 'Year-End Wrapped',
        'es': 'Resumen anual',
        'fr': 'Bilan annuel',
        'pt': 'Resumo annuel',
      },
      'achievements': {
        'en': 'Achievements',
        'es': 'Logros',
        'fr': 'Succès',
        'pt': 'Conquistas',
      },
    };

    return data[key]?[language] ??
        data[key]?['en'] ??
        key;
  }
}

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
    final tabs = [
      'Recommendations',
      'Collections',
      'Monthly Wrapped',
      'Achievements',
      'Year-End Wrapped',
      'Shared Actors',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover & Recaps'),
        actions: [
          const LanguagePicker(),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, index) {
                return ChoiceChip(
                  label: Text(tabs[index]),
                  selected: tab == index,
                  onSelected: (_) {
                    setState(() {
                      tab = index;
                    });
                  },
                );
              },
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                RecommendationsPanel(),
                CollectionsPanel(),
                WrappedPanel(monthly: true),
                AchievementsPanel(),
                WrappedPanel(monthly: false),
                SharedActorsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RECOMMENDATIONS
// -----------------------------------------------------------------------------

class RecommendationsPanel extends StatefulWidget {
  const RecommendationsPanel({super.key});

  @override
  State<RecommendationsPanel> createState() =>
      _RecommendationsPanelState();
}

class _RecommendationsPanelState
    extends State<RecommendationsPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profiles =
        controller.currentAccount?.profiles ?? [];

    final watched = controller.watched;
    final liked = controller.liked;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(
          '🤖 Similarity Recommendations',
          'Profiles can recommend titles to one another. '
              'Recommendations are based on the viewing and like '
              'activity currently stored by the account.',
        ),
        const SizedBox(height: 12),
        if (profiles.length < 2)
          _empty(
            'Add at least two profiles to compare viewing interests.',
          )
        else
          ...profiles.map(
            (profile) {
              final recommendations =
                  _recommendationsForProfile(
                controller,
                profile,
              );

              return Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${watched.length} watched • '
                        '${liked.length} liked',
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ExpansionTile(
                        title: const Text(
                          'Recommended titles',
                        ),
                        subtitle: Text(
                          recommendations.isEmpty
                              ? 'Watch and like more titles to improve recommendations.'
                              : '${recommendations.length} suggestions',
                        ),
                        children: [
                          if (recommendations.isEmpty)
                            const Padding(
                              padding:
                                  EdgeInsets.all(16),
                              child: Text(
                                'No recommendations yet. '
                                'Add more titles to your library and '
                                'build your watch history.',
                              ),
                            )
                          else
                            for (final media
                                in recommendations)
                              ListTile(
                                leading: const Icon(
                                  Icons.movie_outlined,
                                ),
                                title:
                                    Text(media.title),
                                subtitle: const Text(
                                  'Recommended because it matches '
                                  'your current viewing interests.',
                                ),
                                trailing:
                                    IconButton(
                                  icon: const Icon(
                                    Icons
                                        .thumb_up_alt_outlined,
                                  ),
                                  onPressed: () {
                                    controller
                                        .activity
                                        .insert(
                                      0,
                                      ActivityItem(
                                        id: DateTime
                                            .now()
                                            .toIso8601String(),
                                        title:
                                            media.title,
                                        action:
                                            'Recommendation liked',
                                        timestamp:
                                            DateTime.now(),
                                      ),
                                    );

                                    setState(() {});
                                  },
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) =>
                  const _CreateVoteDialog(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text(
            'Create recommendation & vote',
          ),
        ),
      ],
    );
  }

  List<MediaItem> _recommendationsForProfile(
    AppController controller,
    Profile profile,
  ) {
    final watchedIds = controller.watched
        .map((media) => media.id)
        .toSet();

    final likedIds = controller.liked
        .map((media) => media.id)
        .toSet();

    final candidates = controller.library.where(
      (media) {
        if (watchedIds.contains(media.id)) {
          return false;
        }

        if (likedIds.contains(media.id)) {
          return false;
        }

        return true;
      },
    );

    return candidates.take(5).toList();
  }
}

class _CreateVoteDialog extends StatefulWidget {
  const _CreateVoteDialog();

  @override
  State<_CreateVoteDialog> createState() =>
      _CreateVoteDialogState();
}

class _CreateVoteDialogState
    extends State<_CreateVoteDialog> {
  final TextEditingController titleController =
      TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New recommendation',
      ),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: 'Movie or show title',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title =
                titleController.text.trim();

            if (title.isEmpty) {
              return;
            }

            AppController.instance.activity.insert(
              0,
              ActivityItem(
                id: DateTime.now()
                    .toIso8601String(),
                title: title,
                action:
                    'Recommendation created • votes open to everyone',
                timestamp: DateTime.now(),
              ),
            );

            Navigator.pop(context);
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// COLLECTIONS
// -----------------------------------------------------------------------------

class CollectionsPanel extends StatefulWidget {
  const CollectionsPanel({super.key});

  @override
  State<CollectionsPanel> createState() =>
      _CollectionsPanelState();
}

class _CollectionsPanelState
    extends State<CollectionsPanel> {
  @override
  void initState() {
    super.initState();
    AppController.instance.seedCollections();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final prefs =
        controller.currentCollectionPreferences;
    final all = controller.collections;

    final mine = all
        .where(
          (c) =>
              c.createdByProfileId ==
              controller.currentProfile?.id,
        )
        .toList();

    final liked = all
        .where(
          (c) =>
              c.isLikedByCurrentProfile &&
              !mine.contains(c),
        )
        .toList();

    final automatic =
        all.where((c) => c.isAutomatic).toList();

    final custom =
        all.where((c) => !c.isAutomatic).toList();

    final ordered =
        _orderCollections(all, prefs);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hero(
            '📚 Collections',
            'Automatic franchise collections and collaborative custom collections, personalized per profile.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(
                    Icons.create_new_folder_outlined,
                  ),
                  label: const Text(
                    'Create Collection',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _customize,
                icon: const Icon(
                  Icons.tune_rounded,
                ),
                tooltip:
                    'Customize collections',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (ordered.isNotEmpty) ...[
            _hero(
              'All Collections',
              '${automatic.length} automatic • ${custom.length} custom',
            ),
            const SizedBox(height: 8),
            _collectionLayout(
              ordered,
              prefs,
            ),
          ],
          const SizedBox(height: 18),
          for (final section
              in controller.collectionSectionOrder)
            _buildSection(
              section,
              all,
              mine,
              liked,
              prefs,
            ),
        ],
      ),
    );
  }

  List<MediaCollection> _orderCollections(
    List<MediaCollection> source,
    CollectionPreferences prefs,
  ) {
    final list =
        List<MediaCollection>.from(source);

    if (prefs.collectionOrder ==
        'Automatic first') {
      list.sort(
        (a, b) =>
            (a.isAutomatic ? 0 : 1)
                .compareTo(
          b.isAutomatic ? 0 : 1,
        ),
      );
    } else if (prefs.collectionOrder ==
        'Custom first') {
      list.sort(
        (a, b) =>
            (a.isAutomatic ? 1 : 0)
                .compareTo(
          b.isAutomatic ? 1 : 0,
        ),
      );
    }

    return list;
  }

  Widget _buildSection(
    String section,
    List<MediaCollection> all,
    List<MediaCollection> mine,
    List<MediaCollection> liked,
    CollectionPreferences prefs,
  ) {
    final items = switch (section) {
      'Featured Collections' =>
        all.where((c) => c.isFeatured).toList(),
      'My Collections' => mine,
      'Liked Collections' => liked,
      _ => <MediaCollection>[],
    };

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 22,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _hero(
            section,
            section == 'Featured Collections'
                ? 'Automatic and featured collections.'
                : section == 'My Collections'
                    ? 'Collections created by your profiles.'
                    : 'Collections liked by your current profile.',
          ),
          const SizedBox(height: 8),
          _collectionLayout(
            _orderCollections(items, prefs),
            prefs,
          ),
        ],
      ),
    );
  }

  Widget _collectionLayout(
    List<MediaCollection> items,
    CollectionPreferences prefs,
  ) {
    if (prefs.layout == 'List') {
      return Column(
        children: [
          for (final collection in items)
            _collectionCard(collection),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.sizeOf(context).width > 700
                ? 4
                : 2,
        childAspectRatio: .72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        return _collectionGridCard(items[i]);
      },
    );
  }

  List<MediaItem> _mediaFor(MediaCollection c) {
    final controller =
        AppController.instance;

    final result = <MediaItem>[];

    for (final id in c.mediaIds) {
      for (final media in controller.library) {
        if (media.id == id) {
          result.add(media);
          break;
        }
      }
    }

    return result;
  }

  bool _canAddToCollection(
    MediaCollection c,
  ) {
    return !c.isAutomatic &&
        c.canCurrentProfileAdd();
  }

  Widget _collectionGridCard(
    MediaCollection c,
  ) {
    final media = _mediaFor(c);
    final canAdd =
        _canAddToCollection(c);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(c),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _collectionArtwork(
                c,
                media,
                large: true,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                2,
              ),
              child: Text(
                c.name,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                2,
                10,
                6,
              ),
              child: Text(
                '${media.length} titles'
                '${c.isAutomatic ? ' • automatic' : ''}'
                '${c.isShared ? ' • shared' : ' • private'}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                8,
                0,
                8,
                8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canAdd
                      ? () => _addMedia(c)
                      : null,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Add to Collection',
                  ),
                  style:
                      FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionCard(
    MediaCollection c,
  ) {
    final media = _mediaFor(c);
    final controller =
        AppController.instance;

    final canAdd =
        _canAddToCollection(c);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  height: 68,
                  child: _collectionArtwork(
                    c,
                    media,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${media.length} titles'
                        '${c.isShared ? ' • shared' : ' • private'}'
                        '${c.isAutomatic ? ' • automatic' : ''}',
                        style:
                            const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      c.isLikedByCurrentProfile
                          ? 'Unlike collection'
                          : 'Like collection',
                  icon: Icon(
                    c.isLikedByCurrentProfile
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  onPressed: () {
                    controller
                        .toggleCollectionLike(
                      c.id,
                    );
                  },
                ),
                PopupMenuButton<String>(
                  tooltip:
                      'More collection actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'play':
                        _autoPlay(c);
                      case 'manage':
                        _manageContributors(c);
                      case 'delete':
                        controller
                            .deleteCollection(
                          c.id,
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: Text(
                        'Auto Play Collection',
                      ),
                    ),
                    if (c.isShared &&
                        c.canCurrentProfileEdit() &&
                        !c.isAutomatic)
                      const PopupMenuItem(
                        value: 'manage',
                        child: Text(
                          'Manage contributors',
                        ),
                      ),
                    if (!c.isOfficial &&
                        c.canCurrentProfileEdit())
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete collection',
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canAdd
                    ? () => _addMedia(c)
                    : null,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Add to Collection',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionArtwork(
    MediaCollection c,
    List<MediaItem> media, {
    bool large = false,
  }) {
    if (c.posterMode ==
            'Uploaded Image' &&
        c.customPosterUrl != null &&
        c.customPosterUrl!
            .trim()
            .isNotEmpty) {
      return Image.network(
        c.customPosterUrl!,
        width: large ? double.infinity : 52,
        height: large ? double.infinity : 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Icon(
              Icons.collections_bookmark_outlined,
              size: 42,
            ),
          );
        },
      );
    }

    if (media.isEmpty) {
      return Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          size: large ? 52 : 28,
        ),
      );
    }

    final posters = media
        .take(4)
        .map((m) => m.imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();

    if (large && posters.length >= 2) {
      return GridView.count(
        crossAxisCount: 2,
        physics:
            const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final url in posters.take(4))
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.movie_outlined,
                );
              },
            ),
        ],
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(10),
      child: Image.network(
        media.first.imageUrl ?? '',
        width: 52,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Icon(
            Icons.collections_bookmark_outlined,
          );
        },
      ),
    );
  }

  void _addMedia(
    MediaCollection c,
  ) {
    final controller =
        AppController.instance;

    if (!_canAddToCollection(c)) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding:
                const EdgeInsets.all(16),
            children: [
              Text(
                'Add to ${c.name}',
                style:
                    const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a library title to add to this collection.',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 12),
              for (final media
                  in controller.library)
                Card(
                  margin:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      controller
                          .addToCollection(
                        c.id,
                        media.id,
                      );

                      Navigator.pop(
                        context,
                      );

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.movie_outlined,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              media.title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                          if (c.mediaIds
                              .contains(
                            media.id,
                          ))
                            const Icon(
                              Icons.check_circle,
                              color:
                                  Colors.green,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Opens the inline collection details view.
  ///
  /// The individual media entries continue to use the existing
  /// `_mediaTile` and `_collectionMediaGridTile` methods below.
  void _openCollection(
    MediaCollection c,
  ) {
    final prefs =
        AppController.instance
            .currentCollectionPreferences;

    final sortedMedia = _sortItems(
      _mediaFor(c),
      prefs.itemSort,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(c.name),
          ),
          body: ListView(
            padding:
                const EdgeInsets.all(18),
            children: [
              _hero(
                c.name,
                '${sortedMedia.length} titles'
                '${c.isAutomatic ? ' • automatic' : ''}'
                '${c.isShared ? ' • shared' : ' • private'}',
              ),
              const SizedBox(height: 16),
              if (sortedMedia.isEmpty)
                const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'This collection has no titles yet.',
                      ),
                    ),
                  ),
                )
              else if (prefs.itemLayout ==
                  'List')
                ...sortedMedia.map(
                  (media) => _mediaTile(
                    c,
                    media,
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount:
                      sortedMedia.length,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.sizeOf(
                                    context)
                                .width >
                            700
                        ? 4
                        : 2,
                    childAspectRatio: .72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder:
                      (_, index) {
                    final media =
                        sortedMedia[index];

                    return _collectionMediaGridTile(
                      media,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaTile(
    MediaCollection c,
    MediaItem m,
  ) {
    final canRemove =
        c.canCurrentProfileEdit() &&
            !c.isAutomatic;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailsScreen(
                media: m,
              ),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 64,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(8),
                  child: m.imageUrl != null &&
                          m.imageUrl!.isNotEmpty
                      ? Image.network(
                          m.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return const Icon(
                              Icons.movie_outlined,
                            );
                          },
                        )
                      : const Icon(
                          Icons.movie_outlined,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${m.releaseYear ?? ''} • ${m.type}',
                      style:
                          const TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip:
                      'Remove from collection',
                  icon: const Icon(
                    Icons
                        .remove_circle_outline,
                  ),
                  onPressed: () {
                    AppController.instance
                        .removeFromCollection(
                      c.id,
                      m.id,
                    );

                    setState(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionMediaGridTile(
    MediaItem media,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailsScreen(
                media: media,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: media.imageUrl != null &&
                      media.imageUrl!.isNotEmpty
                  ? Image.network(
                      media.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.movie_outlined,
                            size: 42,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.movie_outlined,
                        size: 42,
                      ),
                    ),
            ),
            Padding(
              padding:
                  const EdgeInsets.all(10),
              child: Text(
                media.title,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MediaItem> _sortItems(
    List<MediaItem> items,
    String sort,
  ) {
    final list =
        List<MediaItem>.from(items);

    int cmp(
      MediaItem a,
      MediaItem b,
    ) {
      return a.title
          .toLowerCase()
          .compareTo(
            b.title.toLowerCase(),
          );
    }

    switch (sort) {
      case 'Oldest → Newest':
        list.sort(
          (a, b) =>
              (a.releaseYear ?? 9999)
                  .compareTo(
                    b.releaseYear ?? 9999,
                  ),
        );
      case 'Newest → Oldest':
        list.sort(
          (a, b) =>
              (b.releaseYear ?? -1)
                  .compareTo(
                    a.releaseYear ?? -1,
                  ),
        );
      case 'Shortest → Longest':
        list.sort(
          (a, b) =>
              _duration(a)
                  .compareTo(
                    _duration(b),
                  ),
        );
      case 'Longest → Shortest':
        list.sort(
          (a, b) =>
              _duration(b)
                  .compareTo(
                    _duration(a),
                  ),
        );
      case 'A → Z':
        list.sort(cmp);
      case 'Z → A':
        list.sort(
          (a, b) => cmp(b, a),
        );
      case 'Rating':
        list.sort(
          (a, b) =>
              (b.rating ?? -1)
                  .compareTo(
                    a.rating ?? -1,
                  ),
        );
      case 'Collection order':
      default:
        break;
    }

    return list;
  }

  int _duration(MediaItem m) {
    return m.seasons.fold<int>(
      0,
      (sum, season) =>
          sum +
          ((season['durationSeconds']
                      as num?)
                  ?.toInt() ??
              0),
    );
  }

  void _autoPlay(
    MediaCollection c,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Auto Play ${c.name}',
        ),
        content: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Text(
              'Choose how versions and progression should behave. Each movie remains a separate library item; theatrical and extended cuts are versions of that movie.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  c.autoPlayVersionPreference,
              decoration:
                  const InputDecoration(
                labelText:
                    'Version preference',
              ),
              items: const [
                'Preferred version',
                'Always theatrical',
                'Always extended',
                'Highest quality',
                'Ask me',
              ]
                  .map(
                    (value) =>
                        DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(
                    () => c
                            .autoPlayVersionPreference =
                        value,
                  );
                }
              },
            ),
            SwitchListTile(
              title: const Text(
                'Auto-play next movie/episode',
              ),
              value:
                  c.autoPlayNextEnabled,
              onChanged: (value) {
                setState(
                  () => c
                          .autoPlayNextEnabled =
                      value,
                );
              },
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  c.autoPlayNextTiming,
              decoration:
                  const InputDecoration(
                labelText:
                    'Start next item',
              ),
              items: const [
                'End credits',
                '30 seconds before end',
                '60 seconds before end',
                'When video ends',
              ]
                  .map(
                    (value) =>
                        DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(
                    () => c
                            .autoPlayNextTiming =
                        value,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'TV shows do not show a Skip Intro control. Auto-play only advances to the next episode.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'Close',
            ),
          ),
          FilledButton(
            onPressed: () {
              c.autoPlayEnabled = true;
              Navigator.pop(context);
            },
            child: const Text(
              'Start',
            ),
          ),
        ],
      ),
    );
  }

  void _manageContributors(
    MediaCollection c,
  ) {
    final controller =
        AppController.instance;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (
          context,
          setDialog,
        ) {
          return AlertDialog(
            title: const Text(
              'Collection contributors',
            ),
            content:
                SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'Shared collections can be built together. Select the profiles allowed to add and manage titles.',
                  ),
                  for (final profile in
                      controller.currentAccount
                              ?.profiles ??
                          [])
                    CheckboxListTile(
                      value: c
                          .contributorProfileIds
                          .contains(
                        profile.id,
                      ),
                      title:
                          Text(profile.name),
                      onChanged:
                          profile.id ==
                                  c.createdByProfileId
                              ? null
                              : (value) {
                                  setDialog(
                                    () {
                                      if (value ==
                                          true) {
                                        if (!c
                                            .contributorProfileIds
                                            .contains(
                                          profile.id,
                                        )) {
                                          c.contributorProfileIds
                                              .add(
                                            profile.id,
                                          );
                                        }
                                      } else {
                                        c.contributorProfileIds
                                            .remove(
                                          profile.id,
                                        );
                                      }
                                    },
                                  );
                                },
                    ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );

                  if (mounted) {
                    setState(() {});
                  }
                },
                child: const Text(
                  'Done',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _create() {
    final name =
        TextEditingController();

    final description =
        TextEditingController();

    bool shared = true;
    bool featured = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (
          context,
          setDialog,
        ) {
          return AlertDialog(
            title: const Text(
              'Create custom collection',
            ),
            content:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Collection name',
                    ),
                  ),
                  TextField(
                    controller:
                        description,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Description',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Shared / collaborative',
                    ),
                    subtitle:
                        const Text(
                      'Other profiles can add titles.',
                    ),
                    value: shared,
                    onChanged: (value) {
                      setDialog(
                        () => shared =
                            value,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Feature on Collections page',
                    ),
                    value: featured,
                    onChanged: (value) {
                      setDialog(
                        () => featured =
                            value,
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                child: const Text(
                  'Cancel',
                ),
              ),
              FilledButton(
                onPressed: () {
                  final collectionName =
                      name.text.trim();

                  if (collectionName
                      .isEmpty) {
                    return;
                  }

                  AppController.instance
                      .createCollection(
                    name: collectionName,
                    description:
                        description.text
                            .trim(),
                    shared: shared,
                    featured: featured,
                  );

                  Navigator.pop(
                    context,
                  );
                },
                child: const Text(
                  'Create',
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      name.dispose();
      description.dispose();

      if (mounted) {
        setState(() {});
      }
    });
  }

  void _customize() {
    final controller =
        AppController.instance;

    final draft = controller
        .currentCollectionPreferences
        .copy();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (
          context,
          setDialog,
        ) =>
            AlertDialog(
          title: const Text(
            'Customize Collections',
          ),
          content:
              SingleChildScrollView(
            child: Column(
              children: [
                _drop(
                  'Collection order',
                  draft.collectionOrder,
                  const [
                    'Automatic first',
                    'Custom first',
                    'Manual',
                  ],
                  (value) {
                    setDialog(
                      () => draft
                              .collectionOrder =
                          value!,
                    );
                  },
                ),
                _drop(
                  'Collection presentation',
                  draft.layout,
                  const [
                    'Grid',
                    'List',
                  ],
                  (value) {
                    setDialog(
                      () => draft.layout =
                          value!,
                    );
                  },
                ),
                _drop(
                  'Automatic collections',
                  draft.automaticPosition,
                  const [
                    'Top',
                    'Bottom',
                  ],
                  (value) {
                    setDialog(
                      () => draft
                              .automaticPosition =
                          value!,
                    );
                  },
                ),
                _drop(
                  'Custom collections',
                  draft.customPosition,
                  const [
                    'Top',
                    'Bottom',
                  ],
                  (value) {
                    setDialog(
                      () => draft
                              .customPosition =
                          value!,
                    );
                  },
                ),
                const Divider(),
                _drop(
                  'Inside collection',
                  draft.itemLayout,
                  const [
                    'Grid',
                    'List',
                  ],
                  (value) {
                    setDialog(
                      () => draft.itemLayout =
                          value!,
                    );
                  },
                ),
                _drop(
                  'Movie/show order',
                  draft.itemSort,
                  const [
                    'Collection order',
                    'Oldest → Newest',
                    'Newest → Oldest',
                    'Shortest → Longest',
                    'Longest → Shortest',
                    'A → Z',
                    'Z → A',
                    'Rating',
                  ],
                  (value) {
                    setDialog(
                      () => draft.itemSort =
                          value!,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                controller
                    .updateCollectionPreferences(
                  draft,
                );

                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child:
          DropdownButtonFormField<String>(
        initialValue: value,
        decoration:
            InputDecoration(
          labelText: label,
        ),
        items: values
            .map(
              (item) =>
                  DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

String _badgeForProfile(
  AppController controller,
  String profileId,
) =>
    controller.badgeForProfile(
      profileId,
    );

// -----------------------------------------------------------------------------
// WRAPPED
// -----------------------------------------------------------------------------

class WrappedPanel extends StatelessWidget {
  final bool monthly;

  const WrappedPanel({
    super.key,
    required this.monthly,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final watched =
        List<MediaItem>.from(controller.watched);

    final profiles =
        controller.currentAccount?.profiles ?? [];

    final movies = watched
        .where(_isMovie)
        .toList();

    final shows = watched
        .where((media) => !_isMovie(media))
        .toList();

    final totalRuntime =
        watched.fold<int>(
      0,
      (sum, media) =>
          sum + _mediaDuration(media),
    );

    final mostWatchedMovie =
        _mostFrequentTitle(movies);

    final mostWatchedShow =
        _mostFrequentTitle(shows);

    final recurringActor =
        _mostRecurringActor(watched);

    final rewatchTitles =
        _rewatchFavorites(watched);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _wrappedHero(
          monthly
              ? '🍿 Your Monthly Wrapped'
              : '🎬 Your Year-End Wrapped',
          monthly
              ? 'Your movie and show recap from the watch data currently stored by this account.'
              : 'Your year-end movie and television recap from the watch data currently stored by this account.',
          monthly ? 'MONTHLY' : 'YEAR END',
        ),

        const SizedBox(height: 14),

        if (watched.isEmpty)
          _empty(
            'Watch some movies or shows and your Wrapped recap will start building here.',
          )
        else ...[
          _wrappedStatGrid(
            context,
            [
              _WrappedStat(
                icon: Icons.movie_outlined,
                title: 'Titles watched',
                value: '${watched.length}',
              ),
              _WrappedStat(
                icon: Icons.schedule_outlined,
                title: 'Platform time',
                value:
                    _formatDuration(totalRuntime),
              ),
              _WrappedStat(
                icon: Icons.people_outline,
                title: 'Profiles together',
                value:
                    '${profiles.length}',
              ),
              _WrappedStat(
                icon: Icons.tv_outlined,
                title: 'Shows',
                value: '${shows.length}',
              ),
            ],
          ),

          const SizedBox(height: 18),

          _wrappedSection(
            icon:
                Icons.local_fire_department_outlined,
            title: 'Your biggest watches',
            subtitle:
                'The titles appearing most often in the currently stored watch list.',
            children: [
              if (mostWatchedShow != null)
                _wrappedHighlight(
                  icon: Icons.tv_outlined,
                  label:
                      'Your most watched show',
                  title:
                      mostWatchedShow.title,
                  subtitle:
                      '${mostWatchedShow.count} recorded watch entries',
                  media:
                      mostWatchedShow.media,
                ),
              if (mostWatchedMovie != null)
                _wrappedHighlight(
                  icon: Icons.movie_outlined,
                  label:
                      'Your most watched movie',
                  title:
                      mostWatchedMovie.title,
                  subtitle:
                      '${mostWatchedMovie.count} recorded watch entries',
                  media:
                      mostWatchedMovie.media,
                ),
            ],
          ),

          const SizedBox(height: 14),

          _wrappedSection(
            icon: Icons.people_alt_outlined,
            title: 'Most recurring actor',
            subtitle:
                'The actor appearing across the largest number of watched titles when actor metadata is available.',
            children: [
              if (recurringActor != null)
                _wrappedHighlight(
                  icon: Icons.person_outline,
                  label:
                      'Most recurring actor',
                  title:
                      recurringActor.name,
                  subtitle:
                      '${recurringActor.count} watched titles',
                )
              else
                _wrappedMessage(
                  'Actor recap data will appear when actor metadata is available on watched titles.',
                ),
            ],
          ),

          const SizedBox(height: 14),

          _wrappedSection(
            icon: Icons.replay_outlined,
            title: 'Rewatch favorites',
            subtitle:
                'Titles with repeated watch entries become your strongest rewatch favorites.',
            children: [
              if (rewatchTitles.isEmpty)
                _wrappedMessage(
                  'No repeated watch entries are currently available.',
                )
              else
                for (final item in rewatchTitles)
                  _wrappedMediaRow(
                    item.media,
                    '${item.count}×',
                  ),
            ],
          ),

          const SizedBox(height: 14),

          _wrappedSection(
            icon: Icons.groups_rounded,
            title:
                'Most-watched across profiles',
            subtitle:
                'Titles watched by the most profiles can become shared rewatch favorites.',
            children: [
              if (profiles.length < 2)
                _wrappedMessage(
                  'Add more profiles to build shared-profile viewing statistics.',
                )
              else
                _wrappedMessage(
                  'Exact per-profile watch counts require profile-owned watch events. The current AppController watch list is account-level, so this screen does not invent profile counts.',
                ),
            ],
          ),

          const SizedBox(height: 14),

          _wrappedSection(
            icon:
                Icons.auto_awesome_outlined,
            title:
                'Your Wrapped highlights',
            subtitle:
                'A quick summary of what defined this recap.',
            children: [
              _wrappedFact(
                'Movie time',
                _formatDuration(
                  movies.fold<int>(
                    0,
                    (sum, media) =>
                        sum +
                        _mediaDuration(media),
                  ),
                ),
              ),
              _wrappedFact(
                'Show time',
                _formatDuration(
                  shows.fold<int>(
                    0,
                    (sum, media) =>
                        sum +
                        _mediaDuration(media),
                  ),
                ),
              ),
              _wrappedFact(
                'Total profile time together',
                _formatDuration(totalRuntime),
              ),
              _wrappedFact(
                'Recap period',
                monthly
                    ? 'Monthly view'
                    : 'Year-end view',
              ),
            ],
          ),

          const SizedBox(height: 14),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Platform time is calculated from the runtime represented by the stored watched titles. Exact calendar-month/year totals and exact per-profile totals require watch-event timestamps and profile ownership in the watch history.',
                      style:
                          const TextStyle(
                        color: Colors.white60,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isMovie(MediaItem media) {
    final type =
        media.type.toLowerCase();

    return type.contains('movie') ||
        type.contains('film');
  }

  int _mediaDuration(MediaItem media) {
    return media.seasons.fold<int>(
      0,
      (sum, season) =>
          sum +
          ((season['durationSeconds']
                      as num?)
                  ?.toInt() ??
              0),
    );
  }

  _WrappedTitle? _mostFrequentTitle(
    List<MediaItem> items,
  ) {
    if (items.isEmpty) {
      return null;
    }

    final counts =
        <String, _WrappedTitle>{};

    for (final media in items) {
      final key =
          media.id.trim().isNotEmpty
              ? media.id
              : media.title.toLowerCase();

      final existing = counts[key];

      if (existing == null) {
        counts[key] = _WrappedTitle(
          media: media,
          title: media.title,
          count: 1,
        );
      } else {
        counts[key] = _WrappedTitle(
          media: existing.media,
          title: existing.title,
          count: existing.count + 1,
        );
      }
    }

    final values =
        counts.values.toList();

    values.sort(
      (a, b) {
        final countCompare =
            b.count.compareTo(a.count);

        if (countCompare != 0) {
          return countCompare;
        }

        return a.title
            .toLowerCase()
            .compareTo(
              b.title.toLowerCase(),
            );
      },
    );

    return values.first;
  }

  _WrappedActor? _mostRecurringActor(
    List<MediaItem> items,
  ) {
    final counts =
        <String, _WrappedActor>{};

    for (final media in items) {
      dynamic actors = media.actors;

      if (actors is! Iterable) {
        continue;
      }

      final seenOnTitle =
          <String>{};

      for (final actor in actors) {
        String? name;

        if (actor is String) {
          name = actor.trim();
        } else if (actor is Map) {
          final value =
              actor['name'] ??
              actor['title'] ??
              actor['actor'];

          if (value != null) {
            name = value.toString().trim();
          }
        }

        if (name == null ||
            name.isEmpty) {
          continue;
        }

        final key =
            name.toLowerCase();

        if (!seenOnTitle.add(key)) {
          continue;
        }

        final existing =
            counts[key];

        if (existing == null) {
          counts[key] =
              _WrappedActor(
            name: name,
            count: 1,
          );
        } else {
          counts[key] =
              _WrappedActor(
            name: existing.name,
            count: existing.count + 1,
          );
        }
      }
    }

    if (counts.isEmpty) {
      return null;
    }

    final values =
        counts.values.toList();

    values.sort(
      (a, b) {
        final countCompare =
            b.count.compareTo(a.count);

        if (countCompare != 0) {
          return countCompare;
        }

        return a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            );
      },
    );

    return values.first;
  }

  List<_WrappedTitle>
      _rewatchFavorites(
    List<MediaItem> items,
  ) {
    final counts =
        <String, _WrappedTitle>{};

    for (final media in items) {
      final key =
          media.id.trim().isNotEmpty
              ? media.id
              : media.title.toLowerCase();

      final existing = counts[key];

      if (existing == null) {
        counts[key] = _WrappedTitle(
          media: media,
          title: media.title,
          count: 1,
        );
      } else {
        counts[key] = _WrappedTitle(
          media: existing.media,
          title: existing.title,
          count: existing.count + 1,
        );
      }
    }

    final repeated = counts.values
        .where((item) => item.count > 1)
        .toList();

    repeated.sort(
      (a, b) =>
          b.count.compareTo(a.count),
    );

    return repeated.take(8).toList();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) {
      return '0m';
    }

    final duration =
        Duration(seconds: seconds);

    final days = duration.inDays;
    final hours =
        duration.inHours.remainder(24);
    final minutes =
        duration.inMinutes.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  Widget _wrappedHero(
    String title,
    String subtitle,
    String period,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF451010),
            Color(0xFF181818),
            Color(0xFF101010),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(
              period,
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: 1.4,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrappedStatGrid(
    BuildContext context,
    List<_WrappedStat> stats,
  ) {
    final columns =
        MediaQuery.sizeOf(context).width >= 800
            ? 4
            : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, index) {
        final stat = stats[index];

        return Card(
          child: Padding(
            padding:
                const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  stat.icon,
                  color: Colors.white70,
                ),
                const Spacer(),
                Text(
                  stat.title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _wrappedSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _wrappedHighlight({
    required IconData icon,
    required String label,
    required String title,
    String? subtitle,
    MediaItem? media,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: .045,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior:
                Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: media?.imageUrl != null &&
                    media!.imageUrl!.isNotEmpty
                ? Image.network(
                    media.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return Icon(icon);
                    },
                  )
                : Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrappedMediaRow(
    MediaItem media,
    String trailing,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(bottom: 7),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 58,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(7),
            child: media.imageUrl != null &&
                    media.imageUrl!.isNotEmpty
                ? Image.network(
                    media.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons.movie_outlined,
                      );
                    },
                  )
                : const Icon(
                    Icons.movie_outlined,
                  ),
          ),
        ),
        title: Text(
          media.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        subtitle: Text(
          media.type,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing: Text(
          trailing,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _wrappedFact(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrappedMessage(
    String message,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white54,
          height: 1.4,
        ),
      ),
    );
  }
}

class _WrappedStat {
  final IconData icon;
  final String title;
  final String value;

  const _WrappedStat({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _WrappedTitle {
  final MediaItem media;
  final String title;
  final int count;

  const _WrappedTitle({
    required this.media,
    required this.title,
    required this.count,
  });
}

class _WrappedActor {
  final String name;
  final int count;

  const _WrappedActor({
    required this.name,
    required this.count,
  });
}

// -----------------------------------------------------------------------------
// ACHIEVEMENTS
// -----------------------------------------------------------------------------

class AchievementsPanel
    extends StatelessWidget {
  const AchievementsPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final profiles =
        controller.currentAccount?.profiles ?? [];

    return ListView(
      padding:
          const EdgeInsets.all(18),
      children: [
        _hero(
          '🏆 Achievements',
          'Badges refresh every month and are visible in group chats.',
        ),
        const SizedBox(height: 12),
        ...profiles.map(
          (profile) => Card(
            child: ListTile(
              title: Text(
                '${profile.name} — ${_badgeForProfile(controller, profile.id)}',
              ),
              subtitle:
                  const Text(
                "Based on this profile's monthly watch activity, variety and genres.",
              ),
              leading:
                  const Icon(
                Icons
                    .emoji_events_outlined,
              ),
            ),
          ),
        ),
        if (profiles.isEmpty)
          _empty(
            'Create a profile to start earning achievements.',
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SHARED ACTORS
// -----------------------------------------------------------------------------

class SharedActorsPanel
    extends StatelessWidget {
  const SharedActorsPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final watched =
        controller.watched;

    final movies =
        watched.take(12).toList();

    return ListView(
      padding:
          const EdgeInsets.all(18),
      children: [
        _hero(
          '🎭 Shared Actor Achievements',
          'Celebrate actors, directors and creators shared across profiles.',
        ),
        const SizedBox(height: 12),
        if (movies.isEmpty)
          _empty(
            'Watch some movies or shows to start building shared achievements.',
          )
        else
          ...movies.map(
            (media) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons
                      .movie_creation_outlined,
                ),
                title:
                    Text(media.title),
                subtitle: Text(
                  '${media.type} • Watched by the account',
                ),
                trailing:
                    const Icon(
                  Icons.star_outline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SHARED UI
// -----------------------------------------------------------------------------

Widget _hero(
  String title,
  String sub,
) {
  return Container(
    padding:
        const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius:
          BorderRadius.circular(22),
      gradient:
          const LinearGradient(
        colors: [
          Color(0xFF301010),
          Color(0xFF171717),
        ],
      ),
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 23,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style:
              const TextStyle(
            color: Colors.white60,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _empty(
  String message,
) {
  return Padding(
    padding:
        const EdgeInsets.all(30),
    child: Center(
      child: Text(
        message,
        textAlign:
            TextAlign.center,
        style:
            const TextStyle(
          color: Colors.white54,
        ),
      ),
    ),
  );
}