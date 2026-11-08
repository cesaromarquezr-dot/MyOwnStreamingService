import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../details.dart';
import '../models/media_case_style.dart';
import '../widgets/media_experience_tools.dart';
import '../music.dart';
import 'collections_screen.dart';
import 'theater_home_screen.dart';
import 'virtual_store_screen.dart';

/// A simplified, image-first kiosk home inspired by Redbox navigation.
/// It is a personal owned-library interface: there are no rental or checkout
/// actions, and day/night appearance is a local display preference.
class RedboxHomeScreen extends StatefulWidget {
  const RedboxHomeScreen({super.key});

  @override
  State<RedboxHomeScreen> createState() => _RedboxHomeScreenState();
}

class _RedboxHomeScreenState extends State<RedboxHomeScreen> {
  static const String _dayModeKey = 'redbox_kiosk_day_mode_v1';

  final TextEditingController _searchController = TextEditingController();
  final PageController _menuPageController = PageController();
  String _query = '';
  String _activeMenu = 'all';
  bool _dayMode = false;
  int _menuPage = 0;

  @override
  void initState() {
    super.initState();
    _loadDisplayMode();
  }

  Future<void> _loadDisplayMode() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _dayMode = preferences.getBool(_dayModeKey) ?? false);
  }

  Future<void> _toggleDisplayMode() async {
    final next = !_dayMode;
    setState(() => _dayMode = next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_dayModeKey, next);
  }

  List<MediaItem> get _ownedMedia {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) => item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList(growable: false);
  }

  bool _isMusic(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        type.contains('audio');
  }

  bool _isSeries(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode') ||
        type.contains('special');
  }

  List<MediaItem> _sorted(List<MediaItem> items) => items.toList(growable: false);

  void _openMedia(MediaItem media) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media)),
    );
  }

  void _selectMenu(String menu) {
    setState(() {
      _activeMenu = menu;
      _query = '';
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _menuPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _ownedMedia;
    final query = _query.trim().toLowerCase();
    final matching = query.isEmpty
        ? all
        : all.where((media) => media.title.toLowerCase().contains(query)).toList();
    final movies = _sorted(matching.where((media) => !_isMusic(media) && !_isSeries(media)).toList());
    final series = _sorted(matching.where(_isSeries).toList());
    final albums = _sorted(matching.where(_isMusic).toList());
    final dvds = _sorted(matching.where((media) => MediaCaseStyle.canonicalFormat(media.displayCaseFormat) == 'DVD').toList());
    final bluRays = _sorted(matching.where((media) => MediaCaseStyle.canonicalFormat(media.displayCaseFormat) == 'Blu-ray').toList());
    final ultraHd = _sorted(matching.where((media) => MediaCaseStyle.canonicalFormat(media.displayCaseFormat) == '4K Ultra HD').toList());
    final cds = _sorted(matching.where((media) => MediaCaseStyle.canonicalFormat(media.displayCaseFormat) == 'Audio CD').toList());
    final continueWatching = _sorted(matching.where((media) {
      final progress = AppController.instance.getPlaybackProgress(media.id);
      return progress > 0 && progress < .96 && !_isMusic(media);
    }).toList());
    final recent = _sorted(matching)..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final featured = recent.isEmpty ? null : recent.first;

    final categories = <_KioskCategory>[
      _KioskCategory(id: 'movies', title: 'Movies', subtitle: '${movies.length} titles', icon: Icons.local_movies_rounded, media: movies),
      _KioskCategory(id: 'series', title: 'TV Shows', subtitle: '${series.length} shows & episodes', icon: Icons.live_tv_rounded, media: series),
      _KioskCategory(id: 'music', title: 'Music & Albums', subtitle: '${albums.length} albums and tracks', icon: Icons.album_rounded, media: albums),
      _KioskCategory(id: 'dvd', title: 'DVD', subtitle: '${dvds.length} DVD titles', icon: Icons.album_outlined, media: dvds),
      _KioskCategory(id: 'bluray', title: 'Blu-ray', subtitle: '${bluRays.length} Blu-ray titles', icon: Icons.album_rounded, media: bluRays),
      _KioskCategory(id: '4k', title: '4K Ultra HD', subtitle: '${ultraHd.length} UHD titles', icon: Icons.high_quality_rounded, media: ultraHd),
      _KioskCategory(id: 'cd', title: 'Music CDs', subtitle: '${cds.length} Audio CDs', icon: Icons.disc_full_rounded, media: cds),
      _KioskCategory(id: 'continue', title: 'Continue Watching', subtitle: '${continueWatching.length} in progress', icon: Icons.play_circle_outline_rounded, media: continueWatching),
      _KioskCategory(id: 'new', title: 'New to Your Library', subtitle: 'Recently added titles', icon: Icons.fiber_new_rounded, media: recent),
      _KioskCategory(id: 'recent', title: 'Browse All', subtitle: '${matching.length} owned items', icon: Icons.grid_view_rounded, media: matching),
      _KioskCategory(id: 'collections', title: 'Collections', subtitle: 'Box sets & editions', icon: Icons.inventory_2_rounded, media: all),
      _KioskCategory(id: 'store', title: 'Virtual Store', subtitle: 'Explore the 3D aisles', icon: Icons.storefront_rounded, media: all),
      _KioskCategory(id: 'theater', title: 'Theater Rooms', subtitle: 'Your private auditoriums', icon: Icons.meeting_room_rounded, media: all),
      _KioskCategory(id: 'lounge', title: 'Listening Lounge', subtitle: 'Albums, artists & playlists', icon: Icons.headphones_rounded, media: albums),
    ];

    final shown = query.isNotEmpty
        ? matching
        : switch (_activeMenu) {
            'movies' => movies,
            'series' => series,
            'music' => albums,
            'dvd' => dvds,
            'bluray' => bluRays,
            '4k' => ultraHd,
            'cd' => cds,
            'continue' => continueWatching,
            'new' => recent.take(16).toList(growable: false),
            'recent' => matching,
            _ => const <MediaItem>[],
          };
    final lightBackground = const Color(0xFFF1F3F6);
    final darkBackground = const Color(0xFF090B10);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: _dayMode ? Brightness.light : Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769AA),
          brightness: _dayMode ? Brightness.light : Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: _dayMode ? lightBackground : darkBackground,
        appBar: AppBar(
          backgroundColor: _dayMode ? const Color(0xFFE5EAF0) : darkBackground,
          title: const Text('My Media', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: _dayMode ? 'Switch to night mode' : 'Switch to day mode',
              onPressed: _toggleDisplayMode,
              icon: Icon(_dayMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            ),
            IconButton(
              tooltip: 'Listening Lounge',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MusicScreen()),
              ),
              icon: const Icon(Icons.headphones_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KioskTopper(dayMode: _dayMode, titleCount: all.length),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() {
                          _query = value;
                          if (value.isNotEmpty) _activeMenu = 'all';
                        }),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Find a movie, show, or album',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: _dayMode ? Colors.white : const Color(0xFF171B24),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'CHOOSE A SECTION',
                              style: TextStyle(
                                color: _dayMode ? const Color(0xFF465466) : Colors.white70,
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text('${_menuPage + 1} / ${(categories.length / 4).ceil()}', style: TextStyle(color: _dayMode ? Colors.black54 : Colors.white54, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 204,
                        child: PageView.builder(
                          controller: _menuPageController,
                          itemCount: (categories.length / 4).ceil(),
                          onPageChanged: (page) => setState(() => _menuPage = page),
                          itemBuilder: (context, page) {
                            final start = page * 4;
                            final end = (start + 4).clamp(0, categories.length).toInt();
                            final pageCategories = categories.sublist(start, end);
                            return GridView.builder(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pageCategories.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.35,
                              ),
                              itemBuilder: (context, index) {
                                final category = pageCategories[index];
                                return _KioskMenuTile(
                                  category: category,
                                  dayMode: _dayMode,
                                  selected: _activeMenu == category.id,
                                  onTap: () {
                                    switch (category.id) {
                                      case 'store':
                                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VirtualStoreScreen()));
                                        break;
                                      case 'theater':
                                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TheaterHomeScreen()));
                                        break;
                                      case 'collections':
                                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CollectionsScreen()));
                                        break;
                                      case 'lounge':
                                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MusicScreen()));
                                        break;
                                      default:
                                        _selectMenu(category.id);
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          (categories.length / 4).ceil(),
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _menuPage ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _menuPage
                                  ? const Color(0xFF2489D8)
                                  : (_dayMode ? Colors.black26 : Colors.white30),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LocalCatalogNotice(dayMode: _dayMode),
                      const SizedBox(height: 14),
                      MediaExperienceTools(compact: true, showHeading: true),
                      if (_activeMenu != 'all' && query.isEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Text(categories.firstWhere((item) => item.id == _activeMenu).title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                            TextButton(onPressed: () => setState(() => _activeMenu = 'all'), child: const Text('Show all')),
                          ],
                        ),
                      ],
                      if (featured != null && query.isEmpty && _activeMenu == 'all') ...[
                        const SizedBox(height: 16),
                        _FeaturedMedia(media: featured, onTap: () => _openMedia(featured)),
                      ],
                      if (query.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            '${matching.length} result${matching.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      if (all.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Your owned library will appear here after you import media or connect your home server.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (query.isNotEmpty)
                if (matching.isNotEmpty)
                  _PosterRailSliver(title: 'Search results', items: matching, onTap: _openMedia)
                else
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No matching titles in your owned library.'))))
              else if (_activeMenu != 'all')
                if (shown.isNotEmpty)
                  _PosterRailSliver(title: 'Titles', items: shown, onTap: _openMedia)
                else
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('There are no items in this section yet.'))))
              else ...[
                if (continueWatching.isNotEmpty)
                  _PosterRailSliver(title: 'Continue watching', items: continueWatching, onTap: _openMedia),
                if (movies.isNotEmpty)
                  _PosterRailSliver(title: 'Movies', items: movies, onTap: _openMedia),
                if (series.isNotEmpty)
                  _PosterRailSliver(title: 'Series & episodes', items: series, onTap: _openMedia),
                if (albums.isNotEmpty)
                  _PosterRailSliver(title: 'Albums & music', items: albums, onTap: _openMedia),
                if (recent.isNotEmpty)
                  _PosterRailSliver(title: 'Recently added', items: recent, onTap: _openMedia),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KioskCategory {
  const _KioskCategory({required this.id, required this.title, required this.subtitle, required this.icon, required this.media});
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<MediaItem> media;
}

class _KioskMenuTile extends StatelessWidget {
  const _KioskMenuTile({required this.category, required this.dayMode, required this.selected, required this.onTap});
  final _KioskCategory category;
  final bool dayMode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = category.media.isEmpty ? null : category.media.first;
    final base = dayMode ? const Color(0xFFD8E0E9) : const Color(0xFF273244);
    return Material(
      color: base,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (first != null) CatalogPosterImage(media: first, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.black.withValues(alpha: .88), Colors.black.withValues(alpha: .26)],
                ),
              ),
            ),
            if (selected)
              Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF58B6FF),
                        width: 2.2,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                children: [
                  Icon(category.icon, color: Colors.white, size: 23),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(category.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KioskTopper extends StatelessWidget {
  const _KioskTopper({required this.dayMode, required this.titleCount});
  final bool dayMode;
  final int titleCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dayMode
                ? const [Color(0xFF145B91), Color(0xFF247DB6)]
                : const [Color(0xFF123A63), Color(0xFF1769AA)],
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 9, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 25),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR ENTERTAINMENT KIOSK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 10)),
                  SizedBox(height: 2),
                  Text('Pick something great to watch or hear.', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text('$titleCount\nOWNED', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, height: 1.25)),
          ],
        ),
      );
}

class _LocalCatalogNotice extends StatelessWidget {
  const _LocalCatalogNotice({required this.dayMode});
  final bool dayMode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dayMode ? const Color(0xFFE4EAF1) : const Color(0xFF151C27),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: dayMode ? Colors.black12 : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(Icons.offline_pin_rounded, color: dayMode ? const Color(0xFF315C7D) : const Color(0xFF80B8E8), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your loaded library catalog stays browsable here. Playback still requires an accessible local file or home server.',
                style: TextStyle(color: dayMode ? const Color(0xFF354455) : Colors.white70, fontSize: 10, height: 1.3),
              ),
            ),
          ],
        ),
      );
}

class _FeaturedMedia extends StatelessWidget {
  const _FeaturedMedia({required this.media, required this.onTap});
  final MediaItem media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 210,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CatalogPosterImage(media: media, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xEE05070B)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FEATURED FROM YOUR LIBRARY', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(media.releaseYear?.toString() ?? media.type, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const Positioned(right: 14, bottom: 16, child: Icon(Icons.play_circle_fill_rounded, size: 42, color: Colors.white)),
              ],
            ),
          ),
        ),
      );
}

class _PosterRailSliver extends StatelessWidget {
  const _PosterRailSliver({required this.title, required this.items, required this.onTap});
  final String title;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 9),
                child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              SizedBox(
                height: 178,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final media = items[index];
                    return SizedBox(
                      width: 112,
                      child: InkWell(
                        onTap: () => onTap(media),
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: SizedBox(width: double.infinity, child: CatalogPosterImage(media: media, fit: BoxFit.cover)),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
