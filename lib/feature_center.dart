import 'package:flutter/material.dart';

import 'app_core.dart';

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
          onSelected: LanguageController.instance.set,
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
        'pt': 'Resumo anual',
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
                                subtitle: Text(
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
  State<CollectionsPanel> createState() => _CollectionsPanelState();
}

class _CollectionsPanelState extends State<CollectionsPanel> {
  @override
  void initState() {
    super.initState();
    AppController.instance.seedCollections();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final all = controller.collections;
    final featuredMap = {for (final c in all) c.id: c};
    final featured = <MediaCollection>[for (final id in controller.featuredCollectionOrder) if (featuredMap[id] != null) featuredMap[id]!, ...all.where((c) => c.isFeatured && !controller.featuredCollectionOrder.contains(c.id))];
    final mine = all.where((c) => !c.isOfficial && c.createdByProfileId == controller.currentProfile?.id).toList();
    final liked = all.where((c) => c.isLikedByCurrentProfile && !mine.contains(c)).toList();

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hero('📚 Collections', 'Featured collections, collections created by profiles, and collections you like — all in one place.'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _create, icon: const Icon(Icons.create_new_folder_outlined), label: const Text('Create Collection'))),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: _customize, icon: const Icon(Icons.tune_rounded), tooltip: 'Customize collections'),
          ]),
          const SizedBox(height: 18),
          for (final section in controller.collectionSectionOrder)
            _buildSection(section, featured, mine, liked),
        ],
      ),
    );
  }

  Widget _buildSection(String section, List<MediaCollection> featured, List<MediaCollection> mine, List<MediaCollection> liked) {
    final items = switch (section) {
      'Featured Collections' => featured,
      'My Collections' => mine,
      'Liked Collections' => liked,
      _ => <MediaCollection>[],
    };
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero(section, section == 'Featured Collections' ? 'Official and featured collections curated for your library.' : section == 'My Collections' ? 'Collections created by your profiles.' : 'Collections liked by your current profile.'),
        const SizedBox(height: 8),
        for (final collection in items) _collectionCard(collection),
      ]),
    );
  }

  Widget _collectionCard(MediaCollection collection) {
    final controller = AppController.instance;
    final media = collection.mediaIds.map((id) { final matches = controller.library.where((m) => m.id == id); return matches.isEmpty ? null : matches.first; }).whereType<MediaItem>().toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: _collectionArtwork(collection, media),
        title: Text(collection.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${media.length} titles${collection.isShared ? ' • shared' : ' • private'}${collection.isAutomatic ? ' • automatic' : ''}'),
        trailing: Wrap(spacing: 2, children: [
          IconButton(icon: Icon(collection.isLikedByCurrentProfile ? Icons.favorite : Icons.favorite_border), onPressed: () { controller.toggleCollectionLike(collection.id); }),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'add') _addMedia(collection); if (value == 'delete') controller.deleteCollection(collection.id); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('Add library title')),
              if (!collection.isOfficial) const PopupMenuItem(value: 'delete', child: Text('Delete collection')),
            ],
          ),
        ]),
        onTap: () => _openCollection(collection),
      ),
    );
  }

  Widget _collectionArtwork(MediaCollection collection, List<MediaItem> media) {
    if (collection.posterMode == 'Uploaded Image' && collection.customPosterUrl != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(collection.customPosterUrl!, width: 52, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.collections_bookmark_outlined)));
    }
    if (media.isEmpty) return const CircleAvatar(child: Icon(Icons.collections_bookmark_outlined));
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(media.first.imageUrl ?? '', width: 52, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.collections_bookmark_outlined)));
  }

  void _addMedia(MediaCollection collection) {
    final controller = AppController.instance;
    if (controller.library.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your library is empty.')));
      return;
    }
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final media in controller.library) ListTile(
        leading: const Icon(Icons.movie_outlined), title: Text(media.title), trailing: collection.mediaIds.contains(media.id) ? const Icon(Icons.check, color: Colors.green) : null,
        onTap: () { controller.addToCollection(collection.id, media.id); Navigator.pop(context); setState(() {}); },
      )],
    ));
  }

  void _openCollection(MediaCollection collection) {
    final controller = AppController.instance;
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [Text(collection.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), if (collection.description.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(collection.description, style: const TextStyle(color: Colors.white60))),
        const SizedBox(height: 10),
        if (collection.mediaIds.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No titles in this collection yet.'))),
        for (final id in collection.mediaIds) ...controller.library.where((m) => m.id == id).map((m) => ListTile(leading: const Icon(Icons.play_circle_outline), title: Text(m.title), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { controller.removeFromCollection(collection.id, m.id); Navigator.pop(context); setState(() {}); }))),
      ],
    )));
  }

  void _create() {
    final name = TextEditingController();
    final description = TextEditingController();
    bool shared = true;
    bool featured = false;
    bool automatic = false;
    String posterMode = 'First 4 Posters';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Create custom collection'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Collection name')),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        SwitchListTile(title: const Text('Shared with the account'), value: shared, onChanged: (v) => setDialog(() => shared = v)),
        SwitchListTile(title: const Text('Feature on Collections page'), value: featured, onChanged: (v) => setDialog(() => featured = v)),
        SwitchListTile(title: const Text('Automatic collection'), subtitle: const Text('Keep the collection rule-driven as your library grows.'), value: automatic, onChanged: (v) => setDialog(() => automatic = v)),
        DropdownButtonFormField<String>(initialValue: posterMode, decoration: const InputDecoration(labelText: 'Artwork'), items: const [
          DropdownMenuItem(value: 'First 4 Posters', child: Text('First 4 posters')),
          DropdownMenuItem(value: 'Generated Seasonal', child: Text('Generated seasonal poster')),
          DropdownMenuItem(value: 'Uploaded Image', child: Text('Uploaded image URL')),
        ], onChanged: (v) { if (v != null) setDialog(() => posterMode = v); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (name.text.trim().isEmpty) return; AppController.instance.createCollection(name: name.text, description: description.text, shared: shared, featured: featured, automatic: automatic, posterMode: posterMode); Navigator.pop(context); }, child: const Text('Create'))],
    ))).then((_) { name.dispose(); description.dispose(); setState(() {}); });
  }

  void _customize() {
    final controller = AppController.instance;
    var sectionDraft = List<String>.from(controller.collectionSectionOrder);
    var featuredDraft = List<String>.from(controller.featuredCollectionOrder);
    final names = {for (final c in controller.collections) c.id: c.name};
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Customize Collections'),
      content: SizedBox(width: 460, height: 470, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Drag the collection groups and featured collections into the order you want.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 14),
        const Text('Collection groups', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 175, child: ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: sectionDraft.length, onReorderItem: (oldIndex, newIndex) { setDialog(() { final item = sectionDraft.removeAt(oldIndex); sectionDraft.insert(newIndex, item); }); }, itemBuilder: (_, i) => KeyedSubtree(key: ValueKey('section-$i-${sectionDraft[i]}'), child: Material(color: const Color(0xFF151515), child: ListTile(tileColor: Colors.transparent, leading: const Icon(Icons.drag_handle), title: Text(sectionDraft[i])))))),
        const Divider(),
        const Text('Featured collections', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 175, child: ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: featuredDraft.length, onReorderItem: (oldIndex, newIndex) { setDialog(() { final item = featuredDraft.removeAt(oldIndex); featuredDraft.insert(newIndex, item); }); }, itemBuilder: (_, i) => KeyedSubtree(key: ValueKey('featured-$i-${featuredDraft[i]}'), child: Material(color: const Color(0xFF151515), child: ListTile(tileColor: Colors.transparent, leading: const Icon(Icons.drag_handle), title: Text(names[featuredDraft[i]] ?? 'Featured collection')))))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { controller.reorderCollectionSections(sectionDraft); controller.reorderFeaturedCollections(featuredDraft); Navigator.pop(context); setState(() {}); }, child: const Text('Save'))],
    )));
  }

}

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
    final controller =
        AppController.instance;

    final profiles =
        controller.currentAccount?.profiles ?? [];

    int movieCount = 0;
    int showCount = 0;

    for (final media in controller.watched) {
      final type =
          media.type.toLowerCase();

      if (type.contains('tv') ||
          type.contains('series') ||
          type.contains('show')) {
        showCount++;
      } else {
        movieCount++;
      }
    }

    final totalRuntime =
        movieCount * 100 +
        showCount * 30;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(
          monthly
              ? '📊 Monthly Wrapped'
              : '🎉 Year-End Wrapped',
          monthly
              ? 'This month across the account.'
              : 'December 25–January 10 recap window; '
                  'then archive it.',
        ),

        const SizedBox(height: 12),

        _stat(
          'Total Movie Runtime',
          '$movieCount movies • ${movieCount * 100} min',
        ),

        _stat(
          'Total Series Runtime',
          '$showCount shows • ${showCount * 30} min',
        ),

        _stat(
          'Total Runtime',
          '$totalRuntime min',
        ),

        const SizedBox(height: 12),

        ...profiles.map(
          (profile) => Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  profile.name.isEmpty
                      ? '?'
                      : profile.name[0]
                          .toUpperCase(),
                ),
              ),
              title: Text(profile.name),
              subtitle: Text(
                '${controller.watched.length} watched • '
                '${controller.liked.length} liked',
              ),
              trailing: Text(
                _badgeFor(
                  controller.watched.length,
                  controller.liked.length,
                ),
              ),
            ),
          ),
        ),

        if (!monthly) ...[
          const SizedBox(height: 10),

          _stat(
            'Top 10 watched movies',
            'Shared + individual archive',
          ),

          _stat(
            'Top 10 watched series',
            'Shared + individual archive',
          ),

          _stat(
            'Most shared collection',
            'Calculated from group activity',
          ),

          _stat(
            'Top genres',
            'Movies + shows',
          ),
        ],
      ],
    );
  }
}

String _badgeFor(
  int watchedCount,
  int likedCount,
) {
  if (watchedCount >= 10) {
    return 'The Movie Buff';
  }

  if (likedCount >= 5) {
    return 'The Loveless Romantic';
  }

  return 'The Explorer';
}

// -----------------------------------------------------------------------------
// ACHIEVEMENTS
// -----------------------------------------------------------------------------

class AchievementsPanel extends StatelessWidget {
  const AchievementsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final profiles =
        controller.currentAccount?.profiles ?? [];

    return ListView(
      padding: const EdgeInsets.all(18),
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
                '${profile.name} — '
                '${_badgeFor(controller.watched.length, controller.liked.length)}',
              ),
              subtitle: const Text(
                'Based on variety, genres, watch history '
                'and group activity.',
              ),
              leading: const Icon(
                Icons.emoji_events_outlined,
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

class SharedActorsPanel extends StatelessWidget {
  const SharedActorsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final watched = controller.watched;

    final movies = watched
        .take(12)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(18),
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
                  Icons.movie_creation_outlined,
                ),
                title: Text(media.title),
                subtitle: Text(
                  '${media.type} • Watched by the account',
                ),
                trailing: const Icon(
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
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
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style: const TextStyle(
            color: Colors.white60,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _stat(
  String title,
  String value,
) {
  return Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

Widget _empty(String message) {
  return Padding(
    padding: const EdgeInsets.all(30),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white54,
        ),
      ),
    ),
  );
}