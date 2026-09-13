// FILE: lib/feature_center.dart
// Purpose: Implements the feature center portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'collection_details.dart';
import 'details.dart';

/// Represents one supported application language.
class AppLanguage {
  final String code;
  final String flag;

  /// Name shown in the language's own language/script.
  final String nativeName;

  final String englishName;

  const AppLanguage(
    this.code,
    this.flag,
    this.nativeName,
    this.englishName,
  );
}

/// Global profile-aware language state used by every screen.
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final instance = LanguageController._();

  AppLanguage current = languages.first;

  static const languages = <AppLanguage>[
    AppLanguage('en', '🇬🇧', 'English', 'English'),
    AppLanguage('es', '🇪🇸', 'Español', 'Spanish'),
    AppLanguage('fr', '🇫🇷', 'Français', 'French'),
    AppLanguage('de', '🇩🇪', 'Deutsch', 'German'),
    AppLanguage('pt', '🇵🇹', 'Português', 'Portuguese'),
    AppLanguage('it', '🇮🇹', 'Italiano', 'Italian'),
    AppLanguage('nl', '🇳🇱', 'Nederlands', 'Dutch'),
    AppLanguage('pl', '🇵🇱', 'Polski', 'Polish'),
    AppLanguage('tr', '🇹🇷', 'Türkçe', 'Turkish'),
    AppLanguage('ru', '🇷🇺', 'Русский', 'Russian'),
    AppLanguage('uk', '🇺🇦', 'Українська', 'Ukrainian'),
    AppLanguage('ar', '🇸🇦', 'العربية', 'Arabic'),
    AppLanguage('hi', '🇮🇳', 'हिन्दी', 'Hindi'),
    AppLanguage('zh', '🇨🇳', '中文', 'Chinese'),
    AppLanguage('ja', '🇯🇵', '日本語', 'Japanese'),
    AppLanguage('ko', '🇰🇷', '한국어', 'Korean'),
  ];

  /// Changes the active language and persists it for the current profile.
  Future<void> set(AppLanguage value) async {
    current = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final profileId = AppController.instance.currentProfile?.id;

    await prefs.setString(
      profileId == null
          ? 'app_language'
          : 'profile_language_$profileId',
      value.code,
    );
  }

  Future<void> loadForCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = AppController.instance.currentProfile?.id;

    final code = prefs.getString(
      profileId == null
          ? 'app_language'
          : 'profile_language_$profileId',
    );

    if (code == null) return;

    final match = languages.where((item) => item.code == code);

    if (match.isEmpty) return;

    current = match.first;
    notifyListeners();
  }
}

/// Reusable language picker intended to be placed in any app bar or menu.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) {
        final language = LanguageController.instance.current;

        return PopupMenuButton<AppLanguage>(
          tooltip: 'Language',
          onSelected: LanguageController.instance.set,
          itemBuilder: (_) {
            return [
              for (final item in LanguageController.languages)
                PopupMenuItem<AppLanguage>(
                  value: item,
                  child: Row(
                    children: [
                      Text(item.flag),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.nativeName),
                      ),
                    ],
                  ),
                ),
            ];
          },
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${language.flag} ${language.nativeName}',
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

/// Translation lookup for user-facing strings.
class AppText {
  static String get(String key) {
    final language = LanguageController.instance.current.code;

    const data = <String, Map<String, String>>{
      'language': {
        'en': 'Language',
        'es': 'Idioma',
        'fr': 'Langue',
        'de': 'Sprache',
        'pt': 'Idioma',
        'it': 'Lingua',
        'ru': 'Язык',
        'ar': 'اللغة',
        'zh': '语言',
        'ja': '言語',
        'ko': '언어',
        'hi': 'भाषा',
      },
      'home': {
        'en': 'Home',
        'es': 'Inicio',
        'fr': 'Accueil',
        'de': 'Startseite',
        'pt': 'Início',
        'it': 'Home',
        'ru': 'Главная',
        'ar': 'الرئيسية',
        'zh': '首页',
        'ja': 'ホーム',
        'ko': '홈',
        'hi': 'होम',
      },
      'movies': {
        'en': 'Movies',
        'es': 'Películas',
        'fr': 'Films',
        'de': 'Filme',
        'pt': 'Filmes',
        'it': 'Film',
        'ru': 'Фильмы',
        'ar': 'الأفلام',
        'zh': '电影',
        'ja': '映画',
        'ko': '영화',
        'hi': 'फ़िल्में',
      },
      'tvShows': {
        'en': 'TV Shows',
        'es': 'Series',
        'fr': 'Séries',
        'de': 'Serien',
        'pt': 'Séries',
        'it': 'Serie TV',
        'ru': 'Сериалы',
        'ar': 'المسلسلات',
        'zh': '电视剧',
        'ja': 'テレビ番組',
        'ko': 'TV 프로그램',
        'hi': 'टीवी शो',
      },
      'music': {
        'en': 'Music',
        'es': 'Música',
        'fr': 'Musique',
        'de': 'Musik',
        'pt': 'Música',
        'it': 'Musica',
        'ru': 'Музыка',
        'ar': 'الموسيقى',
        'zh': '音乐',
        'ja': '音楽',
        'ko': '음악',
        'hi': 'संगीत',
      },
      'search': {
        'en': 'Search',
        'es': 'Buscar',
        'fr': 'Rechercher',
        'de': 'Suchen',
        'pt': 'Pesquisar',
        'it': 'Cerca',
        'ru': 'Поиск',
        'ar': 'بحث',
        'zh': '搜索',
        'ja': '検索',
        'ko': '검색',
        'hi': 'खोज',
      },
      'settings': {
        'en': 'Settings',
        'es': 'Configuración',
        'fr': 'Paramètres',
        'de': 'Einstellungen',
        'pt': 'Configurações',
        'it': 'Impostazioni',
        'ru': 'Настройки',
        'ar': 'الإعدادات',
        'zh': '设置',
        'ja': '設定',
        'ko': '설정',
        'hi': 'सेटिनги',
      },
      'recommendations': {
        'en': 'Recommendations',
        'es': 'Recomendaciones',
        'fr': 'Recommandations',
        'de': 'Empfehlungen',
        'pt': 'Recomendações',
        'it': 'Consigliati',
        'ru': 'Рекомендации',
        'ar': 'التوصيات',
        'zh': '推荐',
        'ja': 'おすすめ',
        'ko': '추천',
        'hi': 'अनुशंसाएँ',
      },
      'collections': {
        'en': 'Collections',
        'es': 'Colecciones',
        'fr': 'Collections',
        'de': 'Sammlungen',
        'pt': 'Coleções',
        'it': 'Raccolte',
        'ru': 'Коллекции',
        'ar': 'المجموعات',
        'zh': '收藏集',
        'ja': 'コレクション',
        'ko': '컬렉션',
        'hi': 'संग्रह',
      },
      'monthly': {
        'en': 'Monthly Wrapped',
        'es': 'Resumen mensual',
        'fr': 'Bilan mensuel',
        'de': 'Monatsrückblick',
        'pt': 'Resumo mensal',
        'it': 'Riepilogo mensile',
        'ru': 'Месячный обзор',
        'ar': 'الملخص الشهري',
        'zh': '月度回顾',
        'ja': '月間まとめ',
        'ko': '월간 요약',
        'hi': 'मासिक सारांश',
      },
      'yearly': {
        'en': 'Year-End Wrapped',
        'es': 'Resumen anual',
        'fr': 'Bilan annuel',
        'de': 'Jahresrückblick',
        'pt': 'Resumo anual',
        'it': 'Riepilogo annuale',
        'ru': 'Итоги года',
        'ar': 'ملخص العام',
        'zh': '年度回顾',
        'ja': '年間まとめ',
        'ko': '연말 요약',
        'hi': 'वार्षिक सारांश',
      },
      'achievements': {
        'en': 'Achievements',
        'es': 'Logros',
        'fr': 'Succès',
        'de': 'Erfolge',
        'pt': 'Conquistas',
        'it': 'Obiettivi',
        'ru': 'Достижения',
        'ar': 'الإنجازات',
        'zh': '成就',
        'ja': '実績',
        'ko': '업적',
        'hi': 'उपलब्धियाँ',
      },
      'connectedSports': {
        'en': 'Connected Sports',
        'es': 'Deportes conectados',
        'fr': 'Sports connectés',
        'de': 'Verbundene Sportdienste',
        'pt': 'Desporto conectado',
        'it': 'Sport collegati',
        'ru': 'Подключённый спорт',
        'ar': 'الرياضات المتصلة',
        'zh': '已连接体育',
        'ja': '接続スポーツ',
        'ko': '연결된 스포츠',
        'hi': 'कनेक्टेड स्पोर्ट्स',
      },
    };

    return data[key]?[language] ?? data[key]?['en'] ?? key;
  }
}

/// A Text widget that automatically rebuilds when language changes.
class LocalizedText extends StatelessWidget {
  final String keyName;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LocalizedText(
    this.keyName, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (_, __) {
        return Text(
          AppText.get(keyName),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// FEATURE CENTER
// -----------------------------------------------------------------------------

class FeatureCenterScreen extends StatefulWidget {
  const FeatureCenterScreen({super.key});

  @override
  State<FeatureCenterScreen> createState() => _FeatureCenterScreenState();
}

class _FeatureCenterScreenState extends State<FeatureCenterScreen> {
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
        actions: const [
          LanguagePicker(),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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

class _RecommendationsPanelState extends State<RecommendationsPanel> {
  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profiles = controller.currentAccount?.profiles ?? [];
    final watched = controller.watched;
    final liked = controller.liked;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(
          '🤖 Similarity Recommendations',
          'Profiles can recommend titles to one another. Recommendations are based on the viewing and like activity currently stored by the account.',
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
                  _recommendationsForProfile(controller, profile);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        '${watched.length} watched • ${liked.length} liked',
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ExpansionTile(
                        title: const Text('Recommended titles'),
                        subtitle: Text(
                          recommendations.isEmpty
                              ? 'Watch and like more titles to improve recommendations.'
                              : '${recommendations.length} suggestions',
                        ),
                        children: [
                          if (recommendations.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No recommendations yet. Add more titles to your library and build your watch history.',
                              ),
                            )
                          else
                            for (final media in recommendations)
                              ListTile(
                                leading: const Icon(
                                  Icons.movie_outlined,
                                ),
                                title: Text(media.title),
                                subtitle: const Text(
                                  'Recommended because it matches your current viewing interests.',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.thumb_up_alt_outlined,
                                  ),
                                  onPressed: () {
                                    final now = DateTime.now();

                                    controller.activity.insert(
                                      0,
                                      ActivityItem(
                                        id: now.toIso8601String(),
                                        title: media.title,
                                        action: 'Recommendation liked',
                                        timestamp: now,
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
              builder: (_) => const _CreateVoteDialog(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Create recommendation & vote'),
        ),
      ],
    );
  }

  List<MediaItem> _recommendationsForProfile(
    AppController controller,
    Profile profile,
  ) {
    final watchedIds =
        controller.watched.map((media) => media.id).toSet();

    final likedIds =
        controller.liked.map((media) => media.id).toSet();

    final candidates = controller.library.where(
      (media) =>
          !watchedIds.contains(media.id) &&
          !likedIds.contains(media.id),
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

class _CreateVoteDialogState extends State<_CreateVoteDialog> {
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
      title: const Text('New recommendation'),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: 'Movie or show title',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();

            if (title.isEmpty) return;

            final now = DateTime.now();

            AppController.instance.activity.insert(
              0,
              ActivityItem(
                id: now.toIso8601String(),
                title: title,
                action:
                    'Recommendation created • votes open to everyone',
                timestamp: now,
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

class _CollectionsPanelState extends State<CollectionsPanel> {
  @override
  void initState() {
    super.initState();
    AppController.instance.seedCollections();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final prefs = controller.currentCollectionPreferences;
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

    final ordered = _orderCollections(all, prefs);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return ListView(
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
                    label: const Text('Create Collection'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _customize,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Customize collections',
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
              _collectionLayout(ordered, prefs),
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
        );
      },
    );
  }

  List<MediaCollection> _orderCollections(
    List<MediaCollection> source,
    CollectionPreferences prefs,
  ) {
    final list = List<MediaCollection>.from(source);

    if (prefs.collectionOrder == 'Automatic first') {
      list.sort(
        (a, b) => (a.isAutomatic ? 0 : 1)
            .compareTo(b.isAutomatic ? 0 : 1),
      );
    } else if (prefs.collectionOrder == 'Custom first') {
      list.sort(
        (a, b) => (a.isAutomatic ? 1 : 0)
            .compareTo(b.isAutomatic ? 1 : 0),
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

    final description =
        section == 'Featured Collections'
            ? 'Automatic and featured collections.'
            : section == 'My Collections'
                ? 'Collections created by your profiles.'
                : 'Collections liked by your current profile.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(section, description),
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
        childAspectRatio: .72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        return _collectionGridCard(items[index]);
      },
    );
  }

  List<MediaItem> _mediaFor(MediaCollection collection) {
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

    return result;
  }

  bool _canAddToCollection(MediaCollection collection) {
    return !collection.isAutomatic &&
        collection.canCurrentProfileAdd();
  }

  Widget _collectionGridCard(MediaCollection collection) {
    final media = _mediaFor(collection);
    final canAdd = _canAddToCollection(collection);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(collection),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _collectionArtwork(
                collection,
                media,
                large: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                2,
              ),
              child: Text(
                collection.name,
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
                6,
              ),
              child: Text(
                '${media.length} titles'
                '${collection.isAutomatic ? ' • automatic' : collection.isShared ? ' • shared' : ' • private'}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                8,
                0,
                8,
                8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      canAdd ? () => _addMedia(collection) : null,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                  ),
                  label: const Text('Add to Collection'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
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

  Widget _collectionCard(MediaCollection collection) {
    final media = _mediaFor(collection);
    final controller = AppController.instance;
    final canAdd = _canAddToCollection(collection);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  height: 68,
                  child: _collectionArtwork(
                    collection,
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
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${media.length} titles'
                        '${collection.isShared ? ' • shared' : ' • private'}'
                        '${collection.isAutomatic ? ' • automatic' : ''}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      collection.isLikedByCurrentProfile
                          ? 'Unlike collection'
                          : 'Like collection',
                  icon: Icon(
                    collection.isLikedByCurrentProfile
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  onPressed: () {
                    controller.toggleCollectionLike(
                      collection.id,
                    );
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'More collection actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'play':
                        _autoPlay(collection);
                        break;
                      case 'titles':
                        _showCollectionTitles(collection);
                        break;
                      case 'manage':
                        _manageContributors(collection);
                        break;
                      case 'delete':
                        controller.deleteCollection(
                          collection.id,
                        );
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: Text('Auto Play Collection'),
                    ),
                    const PopupMenuItem(
                      value: 'titles',
                      child: Text(
                        'Browse collection titles',
                      ),
                    ),
                    if (collection.isShared &&
                        collection.canCurrentProfileEdit() &&
                        !collection.isAutomatic)
                      const PopupMenuItem(
                        value: 'manage',
                        child: Text(
                          'Manage contributors',
                        ),
                      ),
                    if (!collection.isOfficial &&
                        collection.canCurrentProfileEdit())
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
                onPressed:
                    canAdd ? () => _addMedia(collection) : null,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                ),
                label: const Text('Add to Collection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionArtwork(
    MediaCollection collection,
    List<MediaItem> media, {
    bool large = false,
  }) {
    if (collection.posterMode == 'Uploaded Image' &&
        collection.customPosterUrl != null &&
        collection.customPosterUrl!.trim().isNotEmpty) {
      return Image.network(
        collection.customPosterUrl!,
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
        physics: const NeverScrollableScrollPhysics(),
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
      borderRadius: BorderRadius.circular(10),
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

  void _showCollectionTitles(MediaCollection collection) {
    final controller = AppController.instance;
    final prefs = controller.currentCollectionPreferences;

    final media = _sortItems(
      _mediaFor(collection),
      prefs.itemSort,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .72,
            minChildSize: .45,
            maxChildSize: .95,
            builder: (
              context,
              scrollController,
            ) {
              if (media.isEmpty) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                      collection.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _empty(
                      'This collection does not contain any library titles yet.',
                    ),
                  ],
                );
              }

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24,
                ),
                children: [
                  Text(
                    collection.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${media.length} titles • ${prefs.itemSort}',
                    style: const TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (prefs.itemLayout == 'Grid')
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: media.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.sizeOf(context).width >
                                    700
                                ? 4
                                : 2,
                        childAspectRatio: .68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (_, index) {
                        return _collectionTitleGridTile(
                          media[index],
                        );
                      },
                    )
                  else
                    for (final item in media)
                      _mediaTile(collection, item),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _collectionTitleGridTile(MediaItem media) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) {
                return MediaDetailsScreen(
                  media: media,
                );
              },
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: media.imageUrl != null &&
                      media.imageUrl!.isNotEmpty
                  ? Image.network(
                      media.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.movie_outlined,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.movie_outlined,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                8,
                8,
                8,
                2,
              ),
              child: Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                8,
                2,
                8,
                8,
              ),
              child: Text(
                '${media.releaseYear ?? ''} • ${media.type}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders one collection title in list layout.
  ///
  /// This remains separate from the grid tile so list-mode controls
  /// can expose collection-specific remove permissions.
  Widget _mediaTile(
    MediaCollection collection,
    MediaItem media,
  ) {
    final canRemove =
        collection.canCurrentProfileEdit() &&
        !collection.isAutomatic;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) {
                return MediaDetailsScreen(
                  media: media,
                );
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: media.imageUrl != null &&
                          media.imageUrl!.isNotEmpty
                      ? Image.network(
                          media.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
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
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${media.releaseYear ?? ''} • ${media.type}',
                      style: const TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove from collection',
                  icon: const Icon(
                    Icons.remove_circle_outline,
                  ),
                  onPressed: () {
                    AppController.instance.removeFromCollection(
                      collection.id,
                      media.id,
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

  /// Sorts collection titles using collection preferences.
  List<MediaItem> _sortItems(
    List<MediaItem> items,
    String sort,
  ) {
    final list = List<MediaItem>.from(items);

    int compareTitle(
      MediaItem a,
      MediaItem b,
    ) {
      return a.title
          .toLowerCase()
          .compareTo(b.title.toLowerCase());
    }

    switch (sort) {
      case 'Oldest → Newest':
        list.sort(
          (a, b) => (a.releaseYear ?? 9999)
              .compareTo(b.releaseYear ?? 9999),
        );
        break;

      case 'Newest → Oldest':
        list.sort(
          (a, b) => (b.releaseYear ?? -1)
              .compareTo(a.releaseYear ?? -1),
        );
        break;

      case 'Shortest → Longest':
        list.sort(
          (a, b) => _duration(a).compareTo(_duration(b)),
        );
        break;

      case 'Longest → Shortest':
        list.sort(
          (a, b) => _duration(b).compareTo(_duration(a)),
        );
        break;

      case 'A → Z':
        list.sort(compareTitle);
        break;

      case 'Z → A':
        list.sort(
          (a, b) => compareTitle(b, a),
        );
        break;

      case 'Rating':
        list.sort(
          (a, b) => (b.rating ?? -1)
              .compareTo(a.rating ?? -1),
        );
        break;

      case 'Collection order':
      default:
        break;
    }

    return list;
  }

  int _duration(MediaItem media) {
    return media.seasons.fold<int>(
      0,
      (sum, season) {
        return sum +
            ((season['durationSeconds'] as num?)
                    ?.toInt() ??
                0);
      },
    );
  }

  void _addMedia(MediaCollection collection) {
    final controller = AppController.instance;

    if (!_canAddToCollection(collection)) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Add to ${collection.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
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
              for (final media in controller.library)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      controller.addToCollection(
                        collection.id,
                        media.id,
                      );
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.movie_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              media.title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          if (collection.mediaIds
                              .contains(media.id))
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
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

  void _openCollection(MediaCollection collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return CollectionDetailsScreen(
            collection: collection,
          );
        },
      ),
    );
  }

  void _autoPlay(MediaCollection collection) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            'Auto Play ${collection.name}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose how versions and progression should behave. Each movie remains a separate library item; theatrical and extended cuts are versions of that movie.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    collection.autoPlayVersionPreference,
                decoration: const InputDecoration(
                  labelText: 'Version preference',
                ),
                items: const [
                  'Preferred version',
                  'Always theatrical',
                  'Always extended',
                  'Highest quality',
                  'Ask me',
                ]
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      collection.autoPlayVersionPreference =
                          value;
                    });
                  }
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Auto-play next movie/episode',
                ),
                value: collection.autoPlayNextEnabled,
                onChanged: (value) {
                  setState(() {
                    collection.autoPlayNextEnabled = value;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    collection.autoPlayNextTiming,
                decoration: const InputDecoration(
                  labelText: 'Start next item',
                ),
                items: const [
                  'End credits',
                  '30 seconds before end',
                  '60 seconds before end',
                  'When video ends',
                ]
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      collection.autoPlayNextTiming =
                          value;
                    });
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                collection.autoPlayEnabled = true;
                Navigator.pop(context);
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }

  void _manageContributors(MediaCollection collection) {
    final controller = AppController.instance;

    showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (
            context,
            setDialog,
          ) {
            return AlertDialog(
              title: const Text(
                'Collection contributors',
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'Shared collections can be built together. Select the profiles allowed to add and manage titles.',
                    ),
                    for (final profile
                        in controller.currentAccount?.profiles ??
                            [])
                      CheckboxListTile(
                        value: collection
                            .contributorProfileIds
                            .contains(profile.id),
                        title: Text(profile.name),
                        onChanged:
                            profile.id ==
                                    collection
                                        .createdByProfileId
                                ? null
                                : (value) {
                                    setDialog(() {
                                      if (value == true) {
                                        if (!collection
                                            .contributorProfileIds
                                            .contains(
                                          profile.id,
                                        )) {
                                          collection
                                              .contributorProfileIds
                                              .add(profile.id);
                                        }
                                      } else {
                                        collection
                                            .contributorProfileIds
                                            .remove(
                                          profile.id,
                                        );
                                      }
                                    });
                                  },
                      ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);

                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _create() {
    final name = TextEditingController();
    final description = TextEditingController();

    bool shared = true;
    bool featured = false;

    showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (
            context,
            setDialog,
          ) {
            return AlertDialog(
              title: const Text(
                'Create custom collection',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(
                        labelText: 'Collection name',
                      ),
                    ),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Shared / collaborative',
                      ),
                      subtitle: const Text(
                        'Other profiles can add titles.',
                      ),
                      value: shared,
                      onChanged: (value) {
                        setDialog(() {
                          shared = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Feature on Collections page',
                      ),
                      value: featured,
                      onChanged: (value) {
                        setDialog(() {
                          featured = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final collectionName =
                        name.text.trim();

                    if (collectionName.isEmpty) return;

                    AppController.instance.createCollection(
                      name: collectionName,
                      description:
                          description.text.trim(),
                      shared: shared,
                      featured: featured,
                    );

                    Navigator.pop(context);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      name.dispose();
      description.dispose();

      if (mounted) {
        setState(() {});
      }
    });
  }

  void _customize() {
    final controller = AppController.instance;
    final draft =
        controller.currentCollectionPreferences.copy();

    showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (
            context,
            setDialog,
          ) {
            return AlertDialog(
              title: const Text(
                'Customize Collections',
              ),
              content: SingleChildScrollView(
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
                        if (value == null) return;

                        setDialog(() {
                          draft.collectionOrder = value;
                        });
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
                        if (value == null) return;

                        setDialog(() {
                          draft.layout = value;
                        });
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
                        if (value == null) return;

                        setDialog(() {
                          draft.automaticPosition = value;
                        });
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
                        if (value == null) return;

                        setDialog(() {
                          draft.customPosition = value;
                        });
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
                        if (value == null) return;

                        setDialog(() {
                          draft.itemLayout = value;
                        });
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
                        if (value == null) return;

                        setDialog(() {
                          draft.itemSort = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    controller.updateCollectionPreferences(
                      draft,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _drop(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
        ),
        items: values
            .map(
              (item) => DropdownMenuItem<String>(
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
    final profiles =
        controller.currentAccount?.profiles ?? [];

    int movieCount = 0;
    int showCount = 0;

    for (final media in controller.watched) {
      final type = media.type.toLowerCase();

      if (type.contains('tv') ||
          type.contains('series') ||
          type.contains('show')) {
        showCount++;
      } else {
        movieCount++;
      }
    }

    final totalRuntime =
        movieCount * 100 + showCount * 30;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(
          monthly
              ? '📊 Monthly Wrapped'
              : '🎉 Year-End Wrapped',
          monthly
              ? 'This month across the account.'
              : 'December 25–January 10 recap window; then archive it.',
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

        // Profile recap cards.
        ...profiles.map(
          (profile) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    profile.name.isEmpty
                        ? '?'
                        : profile.name[0].toUpperCase(),
                  ),
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${controller.watched.length} watched • '
                  '${controller.liked.length} liked',
                ),
                trailing: Text(
                  _badgeForProfile(
                    controller,
                    profile.id,
                  ),
                ),
              ),
            );
          },
        ),

        // Year-end-only statistics.
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

String _badgeForProfile(
  AppController controller,
  String profileId,
) {
  return controller.badgeForProfile(profileId);
}

// -----------------------------------------------------------------------------
// ACHIEVEMENTS
// -----------------------------------------------------------------------------

class AchievementsPanel extends StatelessWidget {
  const AchievementsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
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
          (profile) {
            return Card(
              child: ListTile(
                title: Text(
                  '${profile.name} — '
                  '${_badgeForProfile(controller, profile.id)}',
                ),
                subtitle: const Text(
                  "Based on this profile's monthly watch activity, variety and genres.",
                ),
                leading: const Icon(
                  Icons.emoji_events_outlined,
                ),
              ),
            );
          },
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
    final controller = AppController.instance;
    final watched = controller.watched;
    final movies = watched.take(12).toList();

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
            (media) {
              return Card(
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
              );
            },
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