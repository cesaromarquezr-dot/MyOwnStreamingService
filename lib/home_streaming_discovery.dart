// FILE: lib/home_streaming_discovery.dart
// Purpose: Streaming-style Home discovery, curated collections, and playlist-of-collections flows.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'cinematic_discovery_studio.dart';
import 'collection_details.dart';
import 'details.dart';
import 'home_franchise_progress.dart';
import 'home_arrow_rail.dart';
import 'multiverse_hub.dart';
import 'music.dart';
import 'profile_content_safety.dart';
import 'localization.dart';
import 'player.dart';
import 'recommendation_ownership.dart';
import 'core/services/cinematic_title_metadata_service.dart';

const Color _discoveryAccent = Color(0xFF8B7CFF);
const Color _discoveryPanel = Color(0xFF171722);

String _mediaThemeText(MediaItem media) {
  final fields = <String>[
    media.title,
    media.description ?? '',
    ...media.genres,
    ...media.tags,
    ...media.actors,
    if (media.franchiseName != null) media.franchiseName!,
  ];
  for (final season in media.seasons) {
    fields.addAll(<String>[
      (season['title'] ?? season['name'] ?? season['description'] ?? '')
          .toString(),
    ]);
    final episodes = season['episodes'];
    if (episodes is List) {
      for (final episode in episodes) {
        if (episode is Map) {
          fields.addAll(<String>[
            (episode['title'] ?? episode['name'] ?? '').toString(),
            (episode['description'] ?? '').toString(),
            (episode['genres'] ?? '').toString(),
            (episode['tags'] ?? '').toString(),
          ]);
        }
      }
    }
  }
  return fields.join(' ').toLowerCase();
}

List<MediaItem> _mediaMatchingTheme(
        List<MediaItem> library, List<String> keywords) =>
    library.where((media) {
      final text = _mediaThemeText(media);
      return keywords.any((keyword) => text.contains(keyword));
    }).toList(growable: false);

MediaCollection? _makeVirtualThemeCollection({
  required String themeTitle,
  required List<String> keywords,
  required List<MediaItem> library,
}) {
  final matches = _mediaMatchingTheme(library, keywords);
  if (matches.isEmpty) return null;
  var name = themeTitle
      .replaceAll(' Movies & Episodes', '')
      .replaceAll(' Collection Mix', '')
      .replaceAll(' Movie Mix', '')
      .trim();
  if (!name.toLowerCase().endsWith('collection')) name = '$name Collection';
  final slug = themeTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return MediaCollection(
    id: 'discovery_$slug',
    name: name,
    description:
        'Auto-curated from matching titles, genres, tags, and episode metadata. This discovery collection is temporary and is not saved to your library.',
    isAutomatic: true,
    isShared: false,
    mediaIds: matches.map((media) => media.id).toList(growable: false),
  );
}

/// Streaming-style navigation row. Browse destinations occupy one side, while
/// Live TV and My TV remain on the opposite side. Flutter's Directionality
/// automatically mirrors the two groups for right-to-left locales.
class HomeBrowseNavigation extends StatelessWidget {
  final VoidCallback onExplore;
  final VoidCallback onMovies;
  final VoidCallback onShows;
  final VoidCallback onMusic;
  final VoidCallback onPhysicalMedia;
  final VoidCallback onLiveTv;
  final VoidCallback onMyTv;

  const HomeBrowseNavigation({
    super.key,
    required this.onExplore,
    required this.onMovies,
    required this.onShows,
    required this.onMusic,
    required this.onPhysicalMedia,
    required this.onLiveTv,
    required this.onMyTv,
  });

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: SizedBox(
        height: 48,
        child: Row(
          textDirection: direction,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  textDirection: direction,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tab('For Me', selected: true, onTap: () {}),
                    const SizedBox(width: 7),
                    _tab('Explore', onTap: onExplore),
                    const SizedBox(width: 7),
                    _tab('Movies', onTap: onMovies),
                    const SizedBox(width: 7),
                    _tab('Shows', onTap: onShows),
                    const SizedBox(width: 7),
                    _tab('Music', onTap: onMusic),
                    const SizedBox(width: 7),
                    _tab('Physical Media', onTap: onPhysicalMedia),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: direction,
              children: [
                _tab('Live TV', onTap: onLiveTv),
                const SizedBox(width: 6),
                _tab('My TV', onTap: onMyTv),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label,
      {bool selected = false, required VoidCallback onTap}) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color:
                  selected ? Colors.black : Colors.white.withValues(alpha: .82),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large landscape Home banner with automatic 12-second rotation and manual controls.
class HomeHeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;

  const HomeHeroCarousel({
    super.key,
    required this.items,
    required this.onOpen,
  });

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  Timer? _advanceTimer;
  int _index = 0;
  bool _appIsActive = true;
  VideoPlayerController? _previewController;
  bool _previewMuted = true;
  String? _previewUrl;
  final Map<String, String> _tmdbOverviewsByMediaId = <String, String>{};
  final Set<String> _overviewLookupStarted = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.items.isNotEmpty) {
      _loadPreview(widget.items.first);
      unawaited(_loadOverview(widget.items.first));
    }
    _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant HomeHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.items.length) _index = 0;
    if (oldWidget.items.length != widget.items.length) _scheduleNext();
    if (widget.items.isNotEmpty) {
      unawaited(_loadOverview(widget.items[_index]));
    }
  }

  bool _isMovieOrShow(MediaItem media) {
    if (media.isSeries) return true;
    final type = media.type.trim().toLowerCase();
    // Music and album types use their own catalog description instead of TMDB.
    if (type.contains('album') ||
        type.contains('music') ||
        type == 'track' ||
        type == 'artist' ||
        type == 'audio') {
      return false;
    }
    return type == 'movie' ||
        type == 'film' ||
        type == 'feature' ||
        type == 'feature film' ||
        type.contains('movie') ||
        type.contains('film');
  }

  Future<void> _loadOverview(MediaItem media) async {
    if (!_isMovieOrShow(media) ||
        !CinematicTitleMetadataService.isConfigured ||
        !_overviewLookupStarted.add(media.id)) {
      return;
    }
    try {
      final overview = (await CinematicTitleMetadataService.lookupOverview(
                title: media.title,
                isTv: media.isSeries,
                year: media.releaseYear,
              ))
              ?.trim() ??
          '';
      if (!mounted || overview.isEmpty) return;
      setState(() => _tmdbOverviewsByMediaId[media.id] = overview);
    } catch (_) {
      // Metadata lookups are best-effort; keep the local catalog overview.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive) {
      _scheduleNext();
      final controller = _previewController;
      if (controller != null && controller.value.isInitialized) {
        controller.setVolume(_previewMuted ? 0 : 1);
        controller.play();
      }
    } else {
      _advanceTimer?.cancel();
      _advanceTimer = null;
      _previewController?.pause();
    }
  }

  Future<void> _loadPreview(MediaItem media) async {
    final url = media.trailerUrl?.trim();
    if (url == null || url.isEmpty || !url.startsWith('http')) {
      final old = _previewController;
      _previewController = null;
      _previewUrl = null;
      if (old != null) {
        await old.pause();
        await old.dispose();
      }
      if (mounted) setState(() {});
      return;
    }
    if (_previewUrl == url && _previewController?.value.isInitialized == true) {
      await _previewController!.seekTo(Duration.zero);
      await _previewController!.play();
      return;
    }
    final old = _previewController;
    _previewController = null;
    _previewUrl = url;
    if (old != null) {
      await old.pause();
      await old.dispose();
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _previewController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_previewMuted ? 0 : 1);
      if (!mounted || _previewController != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (_previewController == controller) {
        _previewController = null;
        _previewUrl = null;
      }
      await controller.dispose();
      if (mounted) setState(() {});
    }
  }

  void _scheduleNext() {
    _advanceTimer?.cancel();
    if (!_appIsActive || widget.items.length < 2) return;
    _advanceTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_appIsActive || widget.items.length < 2) return;
      final next = (_index + 1) % widget.items.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      }
      _scheduleNext();
    });
  }

  void _move(int delta) {
    if (widget.items.isEmpty || !_pageController.hasClients) return;
    final next = (_index + delta + widget.items.length) % widget.items.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    _scheduleNext();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advanceTimer?.cancel();
    _previewController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * .54).clamp(340.0, 500.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  _loadPreview(widget.items[value]);
                  unawaited(_loadOverview(widget.items[value]));
                  _scheduleNext();
                },
                itemBuilder: (context, index) =>
                    _buildHeroPage(widget.items[index]),
              ),
              if (widget.items.length > 1) ...[
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _heroArrow(Icons.chevron_left_rounded,
                        () => _move(-1), 'Previous featured title'),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _heroArrow(Icons.chevron_right_rounded,
                        () => _move(1), 'Next featured title'),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 18,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .56),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1} / ${widget.items.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              Positioned(
                left: 24,
                right: 24,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(widget.items.length, (index) {
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic);
                        _scheduleNext();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: index == _index ? 21 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: index == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPage(MediaItem media) {
    final tmdbOverview = _tmdbOverviewsByMediaId[media.id]?.trim();
    // Movie/show heroes prefer TMDB's actual overview. Albums and titles without
    // an exact TMDB match fall back to the overview/description in the catalog.
    final description = tmdbOverview?.isNotEmpty == true
        ? tmdbOverview
        : media.description?.trim();
    final heroMetadata = <String>[];
    final yearLabel = media.displayYearLabel;
    if (yearLabel != null && yearLabel.isNotEmpty) heroMetadata.add(yearLabel);
    final editionLabel = media.displayEditionLabel;
    if (editionLabel != null && editionLabel.isNotEmpty) {
      heroMetadata.add(editionLabel);
    }
    final seasonCount = media.displaySeasonCount;
    if (seasonCount != null) {
      heroMetadata
          .add('$seasonCount ${seasonCount == 1 ? 'Season' : 'Seasons'}');
    }
    if (!media.isSeries &&
        media.editionReleaseYear != null &&
        media.releaseYear != null &&
        media.editionReleaseYear != media.releaseYear) {
      heroMetadata.add('Original release ${media.releaseYear}');
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_previewController != null &&
            _previewUrl == media.trailerUrl?.trim() &&
            _previewController!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _previewController!.value.size.width,
              height: _previewController!.value.size.height,
              child: VideoPlayer(_previewController!),
            ),
          )
        else if (media.imageUrl?.trim().isNotEmpty == true) ...[
          // A dark cover fills the banner behind the main artwork, avoiding
          // blank margins without sacrificing the full original poster/image.
          Positioned.fill(
            child: Image.network(
              media.imageUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: .48),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => _heroFallback(media),
            ),
          ),
          Positioned.fill(
            child: Image.network(
              media.imageUrl!,
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ]
        else
          _heroFallback(media),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.black.withValues(alpha: .03),
                Colors.black.withValues(alpha: .2),
                Colors.black.withValues(alpha: .88),
              ],
              stops: const [0, .35, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: .72)],
              stops: const [.24, 1],
            ),
          ),
        ),
        if (_previewController != null &&
            _previewUrl == media.trailerUrl?.trim() &&
            _previewController!.value.isInitialized)
          Positioned(
            right: 20,
            bottom: 58,
            child: IconButton.filledTonal(
              tooltip: _previewMuted ? 'Unmute preview' : 'Mute preview',
              onPressed: () async {
                setState(() => _previewMuted = !_previewMuted);
                await _previewController?.setVolume(_previewMuted ? 0 : 1);
              },
              icon: Icon(_previewMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded),
            ),
          ),
        Positioned(
          left: 26,
          right: 26,
          bottom: 45,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _discoveryAccent.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(media.type.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1)),
                ),
                const SizedBox(height: 10),
                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 30 : 42,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 18)
                    ],
                  ),
                ),
                if (heroMetadata.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    heroMetadata.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                ],
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'OVERVIEW',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => widget.onOpen(media),
                  icon: Icon(
                      media.playbackUrl?.trim().isNotEmpty == true
                          ? Icons.play_arrow_rounded
                          : Icons.info_outline_rounded,
                      size: 22),
                  label: UniversalText(
                    media.playbackUrl?.trim().isNotEmpty == true
                        ? 'Play now'
                        : 'More info',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroFallback(MediaItem media) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF262238), Color(0xFF101014)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Center(
            child: Icon(
                media.type.toLowerCase().contains('music')
                    ? Icons.music_note_rounded
                    : Icons.movie_creation_outlined,
                size: 86,
                color: Colors.white24)),
      );

  Widget _heroArrow(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: .48),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 31, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ThemedEpisodeEntry {
  final MediaItem parent;
  final Map<String, dynamic>? episode;
  final String title;
  final String detail;
  final String? imageUrl;

  const _ThemedEpisodeEntry({
    required this.parent,
    required this.title,
    required this.detail,
    this.episode,
    this.imageUrl,
  });
}

/// Surfaces themed specials and episodes only when the library metadata supports them.
class HomeThemedEpisodesSection extends StatelessWidget {
  const HomeThemedEpisodesSection({super.key});

  static const List<String> _keywords = [
    'halloween',
    'haunted',
    'scary',
    'spooky',
    'horror',
    'ghost',
    'monster',
    'witch',
    'vampire',
    'pumpkin',
    'cursed',
    'rock bottom',
    'costume',
    'nightmare',
  ];

  List<_ThemedEpisodeEntry> _entries(List<MediaItem> library) {
    final entries = <_ThemedEpisodeEntry>[];
    for (final media in library) {
      var foundEpisode = false;
      for (final season in media.seasons) {
        final rawEpisodes = season['episodes'];
        if (rawEpisodes is! List) continue;
        for (final rawEpisode in rawEpisodes) {
          if (rawEpisode is! Map) continue;
          final episode = Map<String, dynamic>.from(rawEpisode);
          final title =
              (episode['title'] ?? episode['name'] ?? 'Episode').toString();
          final searchable =
              '$title ${episode['description'] ?? ''} ${episode['genres'] ?? ''} ${episode['tags'] ?? ''}'
                  .toLowerCase();
          if (!_keywords.any((keyword) => searchable.contains(keyword))) {
            continue;
          }
          entries.add(_ThemedEpisodeEntry(
            parent: media,
            episode: episode,
            title: title,
            detail: '${media.title} • ${_seasonLabel(season)}',
            imageUrl:
                (episode['imageUrl'] ?? episode['posterUrl'] ?? media.imageUrl)
                    ?.toString(),
          ));
          foundEpisode = true;
        }
      }

      final fields = <String>[
        media.title,
        media.description ?? '',
        ...media.genres,
        ...media.tags,
      ].join(' ').toLowerCase();
      if (!foundEpisode && _keywords.any(fields.contains)) {
        entries.add(_ThemedEpisodeEntry(
          parent: media,
          title: media.title,
          detail: '${media.type} • themed pick',
          imageUrl: media.imageUrl,
        ));
      }
    }
    final unique = <String, _ThemedEpisodeEntry>{};
    for (final entry in entries) {
      final key = '${entry.parent.id}:${entry.episode?['id'] ?? entry.title}';
      unique.putIfAbsent(key, () => entry);
    }
    return unique.values.take(18).toList(growable: false);
  }

  String _seasonLabel(Map<String, dynamic> season) {
    final number = season['seasonNumber'] ??
        season['season_number'] ??
        season['number'] ??
        season['season'];
    return number == null ? 'Special episode' : 'Season $number';
  }

  void _openEntry(BuildContext context, _ThemedEpisodeEntry entry) {
    final episode = entry.episode;
    final episodeId = episode?['id']?.toString();
    final source = episode?['playbackUrl']?.toString() ??
        episode?['streamingUrl']?.toString();
    if (episode != null &&
        episodeId != null &&
        episodeId.isNotEmpty &&
        source != null &&
        source.trim().isNotEmpty) {
      final episodeMedia = MediaItem(
        id: episodeId,
        title: entry.title,
        type: 'episode',
        imageUrl: entry.imageUrl,
        description: episode['description']?.toString(),
        playbackUrl: source,
        trailerUrl: episode['trailerUrl']?.toString(),
      );
      Navigator.of(context).push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/player'),
        builder: (_) => PlayerScreen(
            media: episodeMedia,
            activityLabel: 'Watching ${entry.parent.title}: ${entry.title}'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/details'),
      builder: (_) => MediaDetailsScreen(media: entry.parent),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final visibleLibrary = controller.library
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    final entries = _entries(visibleLibrary);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoverySectionHeader(
              title: 'Themed Episodes',
              subtitle:
                  'Halloween specials, spooky stories, cult-favorite episodes, and more'),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                  'Add episode titles, genres, or tags to your library metadata and themed picks will appear here.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            )
          else
            HomeArrowRail(
              height: 210,
              itemCount: entries.length,
              separatorExtent: 12,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _DiscoveryMediaCard(
                  title: entry.title,
                  subtitle: entry.detail,
                  imageUrl: entry.imageUrl,
                  onTap: () => _openEntry(context, entry),
                  width: 148,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A separate recommendation shelf to complement Continue Watching and Recommended for You.
class HomeYouMayAlsoLikeSection extends StatelessWidget {
  final List<MediaItem> library;
  final List<MediaItem> watched;

  const HomeYouMayAlsoLikeSection(
      {super.key, required this.library, required this.watched});

  List<MediaItem> _recommendations() {
    final controller = AppController.instance;
    final watchedIds = watched.map((m) => m.id).toSet();
    final sortedLibrary = List<MediaItem>.from(library)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final seed = watched.isNotEmpty
        ? watched.first
        : (sortedLibrary.isNotEmpty
            ? sortedLibrary.first
            : (controller.liked.isNotEmpty ? controller.liked.first : null));
    final seedFields = <String>{
      ...(seed?.genres ?? const <String>[]).map((e) => e.toLowerCase()),
      ...(seed?.tags ?? const <String>[]).map((e) => e.toLowerCase()),
    };
    final backendRecommendedIds =
        controller.recommendations.map((item) => item.id).toSet();
    final byId = <String, MediaItem>{};
    for (final item in <MediaItem>[
      ...library,
      ...controller.recommendations,
      ...controller.liked
    ]) {
      if (item.id.trim().isEmpty ||
          item.id == seed?.id ||
          watchedIds.contains(item.id) ||
          isExcludedEntertainmentType(item.type) ||
          !item.isAccessibleTo(controller.currentProfile)) {
        continue;
      }
      byId.putIfAbsent(item.id, () => item);
    }
    int score(MediaItem item) {
      final fields = <String>{...item.genres, ...item.tags}
          .map((e) => e.toLowerCase())
          .toSet();
      final overlap = fields.intersection(seedFields).length;
      final sharedFranchise = seed?.franchiseName?.trim().isNotEmpty == true &&
          seed?.franchiseName?.toLowerCase() ==
              item.franchiseName?.toLowerCase();
      final sharedCredits = <String>{
        ...(seed?.actors ?? const <String>[]).map((e) => e.toLowerCase()),
        ...(seed?.directors ?? const <String>[]).map((e) => e.toLowerCase()),
        ...(seed?.writers ?? const <String>[]).map((e) => e.toLowerCase()),
        ...(seed?.music ?? const <String>[]).map((e) => e.toLowerCase()),
        ...(seed?.studios ?? const <String>[]).map((e) => e.toLowerCase()),
        ...(seed?.companies ?? const <String>[]).map((e) => e.toLowerCase()),
      }.intersection(<String>{
        ...item.actors.map((e) => e.toLowerCase()),
        ...item.directors.map((e) => e.toLowerCase()),
        ...item.writers.map((e) => e.toLowerCase()),
        ...item.music.map((e) => e.toLowerCase()),
        ...item.studios.map((e) => e.toLowerCase()),
        ...item.companies.map((e) => e.toLowerCase()),
      }).length;
      // Only shared metadata establishes relevance. Rating is a tie-breaker,
      // not a substitute for a relationship to the seed title.
      return overlap * 10 + sharedCredits * 5 + (sharedFranchise ? 20 : 0);
    }

    // Backend picks already passed the full-catalog recommendation engine;
    // local candidates must have a real overlap with the current seed.
    final items = byId.values
        .where((item) =>
            backendRecommendedIds.contains(item.id) ||
            (seed != null && score(item) > 0))
        .toList();
    items.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (byRating != 0) return byRating;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items.take(12).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _recommendations();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DiscoverySectionHeader(
            title: 'You May Also Like',
            subtitle: 'More picks based on what you watch and enjoy'),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
                'Your next recommendation will appear here as your library grows.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        else
          HomeArrowRail(
            height: 210,
            itemCount: items.length,
            separatorExtent: 12,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) {
              final media = items[index];
              return _DiscoveryMediaCard(
                title: media.title,
                subtitle:
                    '${media.displayYearLabel ?? ''} ${media.type}${media.displayEditionLabel == null ? '' : ' • ${media.displayEditionLabel}'}'
                        .trim(),
                imageUrl: media.imageUrl,
                isOwned: AppController.instance.isOwned(media.id),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/details'),
                  builder: (_) => MediaDetailsScreen(media: media),
                )),
              );
            },
          ),
      ],
    );
  }
}

/// Home-page shelves driven by people credited in the user's viewing history.
/// Uses only locally known credits and available catalog items; no credit is inferred.
class HomeBecauseYouWatchedPeopleShelves extends StatelessWidget {
  final List<MediaItem> library;
  final List<MediaItem> watched;

  const HomeBecauseYouWatchedPeopleShelves({super.key, required this.library, required this.watched});

  String _norm(String value) => value.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    if (watched.isEmpty) return const SizedBox.shrink();
    final controller = AppController.instance;
    final catalog = <String, MediaItem>{};
    for (final item in <MediaItem>[...library, ...controller.recommendations, ...controller.watched, ...controller.liked]) {
      if (item.id.isNotEmpty && item.isAccessibleTo(controller.currentProfile) && !isExcludedEntertainmentType(item.type)) {
        catalog.putIfAbsent(item.id, () => item);
      }
    }
    final viewed = <MediaItem>[];
    final seen = <String>{};
    for (final item in watched.reversed) {
      if (seen.add(item.id)) viewed.add(item);
    }
    final shelves = <({MediaItem seed, String person, List<MediaItem> items})>[];
    final shelfKeys = <String>{};
    for (final seed in viewed) {
      final people = <String>{...seed.actors, ...seed.directors, ...seed.writers};
      for (final person in people) {
        final normalizedPerson = _norm(person);
        if (normalizedPerson.isEmpty || !shelfKeys.add('${seed.id}:$normalizedPerson')) continue;
        final matches = catalog.values.where((candidate) => candidate.id != seed.id && !watched.any((w) => w.id == candidate.id) && <String>{...candidate.actors, ...candidate.directors, ...candidate.writers}.any((credit) => _norm(credit) == normalizedPerson)).toList();
        if (matches.isEmpty) continue;
        matches.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        shelves.add((seed: seed, person: person, items: matches.take(12).toList()));
        if (shelves.length >= 6) break;
      }
      if (shelves.length >= 6) break;
    }
    if (shelves.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final shelf in shelves) ...[
        _DiscoverySectionHeader(title: 'Because you watched ${shelf.seed.title} featuring ${shelf.person}', subtitle: 'More movies and shows with this actor, director, or screenwriter'),
        HomeArrowRail(height: 210, itemCount: shelf.items.length, separatorExtent: 12, padding: const EdgeInsets.symmetric(horizontal: 48), itemBuilder: (context, index) {
          final media = shelf.items[index];
          return _DiscoveryMediaCard(title: media.title, subtitle: '${media.displayYearLabel ?? ''} ${media.type}'.trim(), imageUrl: media.imageUrl, isOwned: controller.isOwned(media.id), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: '/app/details'), builder: (_) => MediaDetailsScreen(media: media))));
        }),
      ],
    ]);
  }
}

/// Explainable Home rails seeded from the newest title, recent viewing, and
/// recent music listening. Suggestions combine local items with catalog-wide
/// candidates returned by the recommendation backend.
class HomeReasonedRecommendationShelves extends StatelessWidget {
  final List<MediaItem> library;
  final List<MediaItem> watched;

  const HomeReasonedRecommendationShelves({
    super.key,
    required this.library,
    required this.watched,
  });

  int _mediaSimilarity(MediaItem seed, MediaItem candidate) {
    final seedGenres = <String>{
      ...seed.genres.map((value) => value.toLowerCase()),
      ...seed.tags.map((value) => value.toLowerCase()),
    };
    final candidateGenres = <String>{
      ...candidate.genres.map((value) => value.toLowerCase()),
      ...candidate.tags.map((value) => value.toLowerCase()),
    };
    final commonGenres = seedGenres.intersection(candidateGenres).length;
    final commonCredits = <String>{
      ...seed.actors.map((value) => value.toLowerCase()),
      ...seed.directors.map((value) => value.toLowerCase()),
      ...seed.writers.map((value) => value.toLowerCase()),
      ...seed.music.map((value) => value.toLowerCase()),
      ...seed.studios.map((value) => value.toLowerCase()),
      ...seed.companies.map((value) => value.toLowerCase()),
    }.intersection(<String>{
      ...candidate.actors.map((value) => value.toLowerCase()),
      ...candidate.directors.map((value) => value.toLowerCase()),
      ...candidate.writers.map((value) => value.toLowerCase()),
      ...candidate.music.map((value) => value.toLowerCase()),
      ...candidate.studios.map((value) => value.toLowerCase()),
      ...candidate.companies.map((value) => value.toLowerCase()),
    }).length;
    final seedFranchise = (seed.franchiseName ?? '').trim().toLowerCase();
    final candidateFranchise =
        (candidate.franchiseName ?? '').trim().toLowerCase();
    return commonGenres * 12 +
        commonCredits * 18 +
        (seedFranchise.isNotEmpty && seedFranchise == candidateFranchise
            ? 45
            : 0);
  }

  List<MediaItem> _related(MediaItem seed,
      {Set<String> excludeIds = const <String>{}}) {
    final controller = AppController.instance;
    final byId = <String, MediaItem>{};
    for (final item in <MediaItem>[...library, ...controller.recommendations]) {
      if (item.id.trim().isEmpty ||
          item.id == seed.id ||
          excludeIds.contains(item.id) ||
          isExcludedEntertainmentType(item.type) ||
          !item.isAccessibleTo(controller.currentProfile)) {
        continue;
      }
      byId.putIfAbsent(item.id, () => item);
    }
    final matches = byId.values
        .where((candidate) => _mediaSimilarity(seed, candidate) > 0)
        .toList();
    matches.sort((a, b) {
      final scoreCompare =
          _mediaSimilarity(seed, b).compareTo(_mediaSimilarity(seed, a));
      if (scoreCompare != 0) return scoreCompare;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (byRating != 0) return byRating;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return matches.take(12).toList(growable: false);
  }

  List<MediaItem> _relatedAlbumsForTrack(MusicTrack track) {
    final controller = AppController.instance;
    final albumCandidates = <String, MediaItem>{};
    for (final item in <MediaItem>[...library, ...controller.recommendations]) {
      final compactType =
          item.type.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
      if (!<String>{'album', 'musicalbum', 'soundtrack'}
              .contains(compactType) ||
          item.id.trim().isEmpty ||
          !item.isAccessibleTo(controller.currentProfile) ||
          isExcludedEntertainmentType(item.type) ||
          item.title.trim().toLowerCase() == track.album.trim().toLowerCase()) {
        continue;
      }
      albumCandidates.putIfAbsent(item.id, () => item);
    }
    final seedGenres =
        track.allGenreTags.map((value) => value.toLowerCase()).toSet();
    int score(MediaItem album) {
      final albumGenres = <String>{
        ...album.genres.map((value) => value.toLowerCase()),
        ...album.tags.map((value) => value.toLowerCase()),
      };
      var value = seedGenres.intersection(albumGenres).length * 10;
      final artist = track.artist.trim().toLowerCase();
      final artistText = <String>[
        album.title,
        album.description ?? '',
        ...album.music,
        ...album.actors,
        ...album.tags,
      ].join(' ').toLowerCase();
      if (artist.isNotEmpty && artistText.contains(artist)) value += 20;
      return value;
    }

    final matches =
        albumCandidates.values.where((album) => score(album) > 0).toList();
    matches.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return matches.take(12).toList(growable: false);
  }

  Widget _mediaShelf(BuildContext context, String title, String subtitle,
      List<MediaItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscoverySectionHeader(title: title, subtitle: subtitle),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Add more related titles or import genre, cast, and franchise metadata to grow these recommendations.',
              style:
                  TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
            ),
          )
        else
          HomeArrowRail(
            height: 210,
            itemCount: items.length,
            separatorExtent: 12,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) {
              final media = items[index];
              return _DiscoveryMediaCard(
                title: media.title,
                subtitle:
                    '${media.displayYearLabel ?? ''} ${media.type}'.trim(),
                imageUrl: media.imageUrl,
                isOwned: AppController.instance.isOwned(media.id),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/details'),
                  builder: (_) => MediaDetailsScreen(media: media),
                )),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWithTracks(BuildContext context, List<MediaItem> visibleLibrary,
      List<MediaItem> visibleWatched) {
    final added = List<MediaItem>.from(visibleLibrary)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final watchedSeed = visibleWatched.isEmpty ? null : visibleWatched.last;
    final musicStore = MusicLibraryStore.instance;
    final profile = AppController.instance.currentProfile;
    bool trackAllowedForProfile(MusicTrack track) =>
        (!profileBlocksExplicitMusic(profile) || !track.explicit) &&
        (!profileBlocksMatureMusic(profile) || !track.matureTheme);
    final currentTrack = MusicPlaybackController.instance.currentTrack;
    MusicTrack? listened;
    if (currentTrack?.audioUrl?.trim().isNotEmpty == true &&
        trackAllowedForProfile(currentTrack!)) {
      listened = currentTrack;
    } else {
      final recentlyListened = musicStore.tracks
          .where((track) =>
              (musicStore.listenCounts[track.id] ?? 0) > 0 &&
              track.audioUrl?.trim().isNotEmpty == true &&
              trackAllowedForProfile(track))
          .toList()
        ..sort((a, b) => (musicStore.listenCounts[b.id] ?? 0)
            .compareTo(musicStore.listenCounts[a.id] ?? 0));
      if (recentlyListened.isNotEmpty) listened = recentlyListened.first;
    }

    final watchedIds = visibleWatched.map((item) => item.id).toSet();
    final children = <Widget>[];
    if (added.isNotEmpty) {
      final seed = added.first;
      children.add(_mediaShelf(
        context,
        'Because you added “${seed.title}”',
        'More titles connected by genre, people, tags, and franchise',
        _related(seed),
      ));
    }
    if (watchedSeed != null) {
      children.add(_mediaShelf(
        context,
        'Because you watched “${watchedSeed.title}”',
        'Recommended from your viewing history and related catalog metadata',
        _related(watchedSeed, excludeIds: watchedIds),
      ));
    }
    if (listened != null) {
      final track = listened;
      final genreTags = <String>{
        ...track.allGenreTags.map((value) => value.toLowerCase()),
      };
      final relatedTracks = musicStore.tracks.where((candidate) {
        if (candidate.id == track.id ||
            candidate.audioUrl?.trim().isNotEmpty != true ||
            !trackAllowedForProfile(candidate)) {
          return false;
        }
        final candidateGenres = <String>{
          ...candidate.allGenreTags.map((value) => value.toLowerCase()),
        };
        return candidate.artist.toLowerCase() == track.artist.toLowerCase() ||
            genreTags.intersection(candidateGenres).isNotEmpty;
      }).toList()
        ..sort((a, b) {
          final sameArtistA =
              a.artist.toLowerCase() == track.artist.toLowerCase() ? 1 : 0;
          final sameArtistB =
              b.artist.toLowerCase() == track.artist.toLowerCase() ? 1 : 0;
          final byArtist = sameArtistB.compareTo(sameArtistA);
          if (byArtist != 0) return byArtist;
          final countCompare = (musicStore.listenCounts[b.id] ?? 0)
              .compareTo(musicStore.listenCounts[a.id] ?? 0);
          return countCompare != 0
              ? countCompare
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      children.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiscoverySectionHeader(
            title: 'Because you listened to “${track.title}”',
            subtitle: 'Songs related by artist and genre',
          ),
          if (relatedTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Listen to more songs or import playable tracks to build music recommendations.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else
            HomeArrowRail(
              height: 176,
              itemCount: relatedTracks.length,
              separatorExtent: 12,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemBuilder: (context, index) =>
                  _HomeReasonedTrackCard(track: relatedTracks[index]),
            ),
          const SizedBox(height: 14),
          _mediaShelf(
            context,
            'Albums related to “${track.title}”',
            'Catalog albums matched by genre and credited artists; status shows whether each album is in your library.',
            _relatedAlbumsForTrack(track),
          ),
        ],
      ));
    }
    return Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, _) {
        final profile = AppController.instance.currentProfile;
        if (profile == null) return const SizedBox.shrink();
        final visibleLibrary = library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        final visibleWatched = watched
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        return AnimatedBuilder(
          animation: MusicLibraryStore.instance,
          builder: (context, _) => AnimatedBuilder(
            animation: MusicPlaybackController.instance,
            builder: (context, __) =>
                _buildWithTracks(context, visibleLibrary, visibleWatched),
          ),
        );
      },
    );
  }
}

class _HomeReasonedTrackCard extends StatelessWidget {
  final MusicTrack track;
  const _HomeReasonedTrackCard({required this.track});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 138,
        child: Material(
          color: _discoveryPanel,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (track.audioUrl?.trim().isNotEmpty != true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'This track has no playable audio source configured yet.')),
                );
                return;
              }
              unawaited(MusicPlaybackController.instance.play(track));
            },
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(fit: StackFit.expand, children: [
                          if (track.artworkUrl?.trim().isNotEmpty == true)
                            Image.network(track.artworkUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFF252532),
                                    child: Icon(Icons.music_note_rounded)))
                          else
                            const ColoredBox(
                                color: Color(0xFF252532),
                                child: Center(
                                    child: Icon(Icons.music_note_rounded,
                                        size: 34))),
                          const Positioned(
                            top: 6,
                            left: 6,
                            child: RecommendationOwnershipBadge(
                                isOwned: true, compact: true),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)),
                    Text(track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ]),
            ),
          ),
        ),
      );
}

/// Compact Home shelves that compare profile-owned titles with complete
/// franchise/saga or cinematic-universe totals when trusted catalog metadata
/// provides those totals.
class HomeFranchiseSagaHub extends StatelessWidget {
  const HomeFranchiseSagaHub({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final profile = controller.currentProfile;
        if (profile == null) return const SizedBox.shrink();
        final visibleLibrary = controller.library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        final catalogFranchiseGroups =
            HomeFranchiseProgressLogic.franchiseSagaGroups(
          visibleLibrary,
          collections: controller.collections,
        );
        final franchiseGroups =
            HomeFranchiseProgressLogic.franchiseSagaExamples(
          visibleLibrary,
          catalogFranchiseGroups,
        );
        final catalogUniverseGroups =
            HomeFranchiseProgressLogic.cinematicUniverseGroups(visibleLibrary);
        final universeGroups =
            HomeFranchiseProgressLogic.cinematicUniverseExamples(
          visibleLibrary,
          catalogUniverseGroups,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeFranchiseProgressShelf(
                title: 'Franchise & Saga Hub',
                subtitle: 'Track the movies and shows you own in each saga',
                emptyMessage:
                    'No franchise or saga links found yet. Import franchise metadata to start tracking your collection.',
                groups: franchiseGroups,
                isUniverse: false,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: '/app/franchise-navigator',
                    ),
                    builder: (_) => const FranchiseNavigatorScreen(),
                  ),
                ),
              ),
              _HomeFranchiseProgressShelf(
                title: 'Cinematic Universe Hub',
                subtitle:
                    'See your collection progress across connected worlds',
                emptyMessage:
                    'No cinematic-universe links found yet. Import universe memberships to see your progress.',
                groups: universeGroups,
                isUniverse: true,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: '/app/cinematic-universe',
                    ),
                    builder: (_) => const CinematicDiscoveryStudioScreen(),
                  ),
                ),
              ),
              MultiverseHubHomeShelf(
                library: visibleLibrary,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: '/app/multiverse-hub',
                    ),
                    builder: (_) =>
                        MultiverseHubScreen(library: visibleLibrary),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFranchiseProgressShelf extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<HomeFranchiseProgressGroup> groups;
  final bool isUniverse;
  final VoidCallback onViewAll;

  const _HomeFranchiseProgressShelf({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.groups,
    required this.isUniverse,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscoverySectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: TextButton(
            onPressed: onViewAll,
            child: const UniversalText('View all'),
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF171722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          )
        else
          HomeArrowRail(
            height: 184,
            itemCount: groups.length,
            separatorExtent: 10,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) => _HomeFranchiseProgressCard(
              group: groups[index],
              isUniverse: isUniverse,
            ),
          ),
      ],
    );
  }
}

class _HomeFranchiseProgressCard extends StatelessWidget {
  final HomeFranchiseProgressGroup group;
  final bool isUniverse;

  const _HomeFranchiseProgressCard({
    required this.group,
    required this.isUniverse,
  });

  @override
  Widget build(BuildContext context) {
    final total = group.totalTitles;
    final percent = group.completionPercent;
    return SizedBox(
      width: 284,
      child: Material(
        color: const Color(0xFF171722),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: RouteSettings(
                name: isUniverse
                    ? '/app/cinematic-universe/${group.id}'
                    : '/app/franchise/${group.id}',
              ),
              builder: (_) => _HomeFranchiseProgressDetailsScreen(
                group: group,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isUniverse
                          ? Icons.auto_awesome_rounded
                          : Icons.account_tree_rounded,
                      color: _discoveryAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ],
                ),
                if (group.isFeaturedExample) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'FEATURED EXAMPLE • catalog totals may be refreshed by metadata import',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        total == null
                            ? '${group.ownedTotalTitles} titles owned'
                            : '${group.ownedTotalTitles} / $total titles',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Color(0xFF9DE5B0),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                if (group.completionFraction != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: group.completionFraction,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF9DE5B0),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Full catalog total not imported',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                const SizedBox(height: 9),
                _HomeHubCountRow(
                  label: 'Movies you own',
                  owned: group.ownedMovies,
                  total: group.totalMovies,
                ),
                const SizedBox(height: 3),
                _HomeHubCountRow(
                  label: 'Shows you own',
                  owned: group.ownedShows,
                  total: group.totalShows,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHubCountRow extends StatelessWidget {
  final String label;
  final int owned;
  final int? total;

  const _HomeHubCountRow({
    required this.label,
    required this.owned,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
        Text(
          total == null ? '$owned' : '$owned / $total',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _HomeFranchiseProgressDetailsScreen extends StatelessWidget {
  final HomeFranchiseProgressGroup group;

  const _HomeFranchiseProgressDetailsScreen({
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final total = group.totalTitles;
    final percent = group.completionPercent;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B10),
        title: Text(group.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF171722),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.type,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  total == null
                      ? '${group.ownedTotalTitles} titles owned'
                      : '${group.ownedTotalTitles} / $total titles owned',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (percent != null) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: group.completionFraction,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF9DE5B0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('$percent% complete',
                      style: const TextStyle(color: Color(0xFF9DE5B0))),
                ] else ...[
                  const SizedBox(height: 5),
                  const Text(
                    'The complete catalog total is not available yet. Owned counts below are based on titles indexed for this profile.',
                    style: TextStyle(color: Colors.white54, height: 1.35),
                  ),
                ],
                if (group.exampleNote != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    group.exampleNote!,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.35),
                  ),
                ],
                const Divider(height: 24, color: Colors.white12),
                _HomeHubCountRow(
                  label: 'Movies you own',
                  owned: group.ownedMovies,
                  total: group.totalMovies,
                ),
                const SizedBox(height: 7),
                _HomeHubCountRow(
                  label: 'Shows you own',
                  owned: group.ownedShows,
                  total: group.totalShows,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 24, 2, 10),
            child: Text(
              'Titles you own',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          if (group.ownedTitles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No titles from this group are currently indexed in your profile library. The reference examples below do not count as owned.',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.35),
              ),
            ),
          for (final media in group.ownedTitles)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 45,
                  height: 62,
                  child: media.imageUrl?.trim().isNotEmpty == true
                      ? Image.network(
                          media.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF252532),
                            child: Icon(Icons.movie_outlined),
                          ),
                        )
                      : const ColoredBox(
                          color: Color(0xFF252532),
                          child: Icon(Icons.movie_outlined),
                        ),
                ),
              ),
              title: Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${_homeMediaTypeLabel(media.type)} • ${media.displayYearLabel ?? 'Year unknown'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/details'),
                  builder: (_) => MediaDetailsScreen(media: media),
                ),
              ),
            ),
          if (group.exampleTitles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 22, 2, 4),
              child: Text('Example catalog titles',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                  'Reference examples only. A check mark means a matching title was found in your profile library; unchecked items are not counted as owned.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 11, height: 1.35)),
            ),
            for (final example in group.exampleTitles)
              Builder(builder: (context) {
                final aliases = <String>{
                  _normalizeHomeCatalogTitle(example.title),
                  ...example.aliases.map(_normalizeHomeCatalogTitle),
                };
                final owned = group.ownedTitles.where((media) {
                  if (_homeMediaTypeLabel(media.type).toLowerCase() !=
                      example.type.toLowerCase()) {
                    return false;
                  }
                  final candidates = <String>{
                    _normalizeHomeCatalogTitle(media.title),
                    _normalizeHomeCatalogTitle(media.originalTitle ?? ''),
                    _normalizeHomeCatalogTitle(media.canonicalTitle ?? ''),
                  }..remove('');
                  return candidates.any(aliases.contains);
                }).toList(growable: false);
                final found = owned.isNotEmpty;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      found
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: found ? const Color(0xFF9DE5B0) : Colors.white38),
                  title: Text(example.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: found ? Colors.white : Colors.white70)),
                  subtitle: Text(
                      '${example.type} · ${found ? 'Found in your library' : 'Not matched in your library'}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: found
                      ? const Icon(Icons.chevron_right_rounded,
                          color: Colors.white54)
                      : null,
                  onTap: found
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              settings:
                                  const RouteSettings(name: '/app/details'),
                              builder: (_) =>
                                  MediaDetailsScreen(media: owned.first)))
                      : null,
                );
              }),
          ],
        ],
      ),
    );
  }
}

String _normalizeHomeCatalogTitle(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _homeMediaTypeLabel(String type) {
  final value = type.toLowerCase();
  if (value.contains('movie') || value.contains('film')) return 'Movie';
  if (value.contains('tv') ||
      value.contains('show') ||
      value.contains('series') ||
      value.contains('episode')) {
    return 'TV Show';
  }
  return type;
}

/// Shows collection-level actions plus a horizontal preview of each collection's members.
class HomeCollectionShelves extends StatelessWidget {
  const HomeCollectionShelves({super.key});

  List<MediaItem> _itemsFor(MediaCollection collection) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final byId = <String, MediaItem>{
      for (final media in controller.library)
        if (media.isAccessibleTo(profile)) media.id: media,
    };
    return collection.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList(growable: false);
  }

  void _openCollection(BuildContext context, MediaCollection collection) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/collection-details'),
      builder: (_) => CollectionDetailsScreen(collection: collection),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final visibleLibrary = controller.library
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    final collections = List<MediaCollection>.from(controller.collections)
        .where((collection) =>
            (collection.isShared ||
                collection.createdByProfileId == profile?.id) &&
            (_itemsFor(collection).isNotEmpty || collection.mediaIds.isEmpty))
        .toList()
      ..sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final hasActionCollection = collections.any((collection) =>
        '${collection.name} ${collection.description}'
            .toLowerCase()
            .contains('action'));
    if (!hasActionCollection) {
      final actionCollection = _makeVirtualThemeCollection(
        themeTitle: 'Action Movies',
        keywords: const [
          'action',
          'adventure',
          'martial arts',
          'spy',
          'superhero'
        ],
        library: visibleLibrary,
      );
      if (actionCollection != null) collections.insert(0, actionCollection);
    }
    final visible = collections.take(4).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiscoverySectionHeader(
            title: 'Collections For You',
            subtitle:
                'Explore a collection, then browse every movie and show inside it',
            trailing: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/app/page/collections'),
                builder: (_) => const DiscoveryAllCollectionsScreen(),
              )),
              child: const UniversalText('All collections'),
            ),
          ),
          if (visible.isNotEmpty)
            HomeArrowRail(
              height: 112,
              itemCount: visible.length,
              separatorExtent: 10,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemBuilder: (context, index) {
                final collection = visible[index];
                final count = _itemsFor(collection).length;
                return SizedBox(
                  width: 236,
                  child: Material(
                    color: const Color(0xFF171722),
                    borderRadius: BorderRadius.circular(15),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openCollection(context, collection),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _discoveryAccent.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                collection.isAutomatic
                                    ? Icons.auto_awesome_mosaic_rounded
                                    : Icons.collections_bookmark_rounded,
                                color: _discoveryAccent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(collection.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('$count titles',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 11)),
                                  if (collection.isAutomatic)
                                    const Text('Auto-curated',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 9)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                  'Create or import a collection to see its title rail here.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          for (final collection in visible) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openCollection(context, collection),
                      child: Text(collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openCollection(context, collection),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const UniversalText('Details'),
                  ),
                ],
              ),
            ),
            _CollectionMemberRail(
                items: _itemsFor(collection),
                collection: collection,
                onOpenCollection: () => _openCollection(context, collection)),
          ],
        ],
      ),
    );
  }
}

class _CollectionMemberRail extends StatelessWidget {
  final MediaCollection collection;
  final List<MediaItem> items;
  final VoidCallback onOpenCollection;

  const _CollectionMemberRail(
      {required this.items,
      required this.collection,
      required this.onOpenCollection});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Material(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onOpenCollection,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.collections_bookmark_outlined),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        collection.description.isEmpty
                            ? 'View collection details and add titles.'
                            : collection.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12))),
                const Icon(Icons.chevron_right_rounded)
              ]),
            ),
          ),
        ),
      );
    }
    return HomeArrowRail(
      height: 184,
      itemCount: items.length,
      separatorExtent: 11,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      itemBuilder: (context, index) {
        final item = items[index];
        return _DiscoveryMediaCard(
          title: item.title,
          subtitle: item.type,
          imageUrl: item.imageUrl,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/app/details'),
            builder: (_) => MediaDetailsScreen(media: item),
          )),
          width: 124,
          posterOnly: true,
        );
      },
    );
  }
}

/// Default search-screen discovery: popular searches, trending searches, playlists and collections.
class SearchDiscoveryLanding extends StatelessWidget {
  final ValueChanged<String> onSearch;

  const SearchDiscoveryLanding({super.key, required this.onSearch});

  static const List<Map<String, String>> _popular = [
    {'label': 'Marvel', 'query': 'Marvel'},
    {'label': 'Halloween', 'query': 'Halloween'},
    {'label': 'Comedy', 'query': 'Comedy'},
    {'label': 'Action Movies', 'query': 'Action'},
    {'label': 'Family', 'query': 'Family'},
    {'label': 'Romance', 'query': 'Romance'},
  ];
  static const List<Map<String, String>> _trending = [
    {'label': 'Animation', 'query': 'Animation'},
    {'label': 'Superheroes', 'query': 'Superhero'},
    {'label': 'Horror', 'query': 'Horror'},
    {'label': 'Sitcoms', 'query': 'Sitcom'},
    {'label': 'Adventure', 'query': 'Adventure'},
    {'label': 'Soundtracks', 'query': 'Soundtrack'},
  ];

  @override
  Widget build(BuildContext context) {
    final collections =
        List<MediaCollection>.from(AppController.instance.collections)
          ..sort((a, b) {
            if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
    final featured = collections.where((c) => c.isFeatured).take(4).toList();
    final collectionCards =
        (featured.isNotEmpty ? featured : collections).take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscoverySectionHeader(
            title: 'Popular Searches',
            subtitle: 'Start with a popular genre or theme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popular
                .map((entry) => _SearchPill(
                    label: entry['label']!,
                    onTap: () => onSearch(entry['query']!)))
                .toList(),
          ),
        ),
        _DiscoverySectionHeader(
            title: 'Trending Searches',
            subtitle: 'Quick shortcuts into popular discovery topics'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trending
                .map((entry) => _SearchPill(
                    label: entry['label']!,
                    onTap: () => onSearch(entry['query']!)))
                .toList(),
          ),
        ),
        _DiscoverySectionHeader(
          title: 'Featured',
          subtitle: 'Curated journeys through movies, shows and collections',
          trailing: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/app/page/playlists'),
              builder: (_) => const DiscoveryPlaylistsScreen(),
            )),
            icon: const Icon(Icons.queue_music_rounded, size: 17),
            label: const UniversalText('Playlists'),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: [
              _FeaturedDiscoveryCard(
                title: 'Playlists',
                subtitle: 'Collections of collections',
                icon: Icons.queue_music_rounded,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/app/page/playlists'),
                  builder: (_) => const DiscoveryPlaylistsScreen(),
                )),
              ),
              const SizedBox(width: 10),
              _FeaturedDiscoveryCard(
                  title: 'Halloween & Spooky',
                  subtitle: 'Movies and themed episodes',
                  icon: Icons.nights_stay_rounded,
                  onTap: () => onSearch('Halloween')),
              const SizedBox(width: 10),
              _FeaturedDiscoveryCard(
                  title: 'Action Movies',
                  subtitle: 'Fast-paced favorites',
                  icon: Icons.bolt_rounded,
                  onTap: () => onSearch('Action')),
              const SizedBox(width: 10),
              _FeaturedDiscoveryCard(
                  title: 'Comedy Night',
                  subtitle: 'Movies and sitcom episodes',
                  icon: Icons.theater_comedy_rounded,
                  onTap: () => onSearch('Comedy')),
            ],
          ),
        ),
        _DiscoverySectionHeader(
          title: 'All Collections',
          subtitle: collections.isEmpty
              ? 'Your collections will appear here'
              : '${collections.length} collections in your library',
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/app/page/collections'),
              builder: (_) => const DiscoveryAllCollectionsScreen(),
            )),
            child: const UniversalText('See all'),
          ),
        ),
        if (collectionCards.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
                'No collections yet. Create one from a title or import your existing collections.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        else
          SizedBox(
            height: 166,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: collectionCards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final collection = collectionCards[index];
                final poster = _posterForCollection(collection);
                return _CollectionSearchCard(
                  collection: collection,
                  imageUrl: poster,
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    settings: const RouteSettings(
                        name: '/app/page/collection-details'),
                    builder: (_) =>
                        CollectionDetailsScreen(collection: collection),
                  )),
                );
              },
            ),
          ),
        const SizedBox(height: 22),
      ],
    );
  }

  String? _posterForCollection(MediaCollection collection) {
    if (collection.customPosterUrl?.trim().isNotEmpty == true) {
      return collection.customPosterUrl;
    }
    final ids = collection.mediaIds.toSet();
    for (final media in AppController.instance.library) {
      if (ids.contains(media.id) && media.imageUrl?.trim().isNotEmpty == true) {
        return media.imageUrl;
      }
    }
    return null;
  }
}

class DiscoveryAllCollectionsScreen extends StatelessWidget {
  const DiscoveryAllCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final collections = List<MediaCollection>.from(controller.collections)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
          title: const UniversalText('All Collections'),
          backgroundColor: const Color(0xFF090909)),
      body: collections.isEmpty
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No collections found yet. Add a collection to start organizing movies and shows.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60))))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final collection = collections[index];
                final items = _itemsFor(collection);
                return _CollectionListTile(
                  collection: collection,
                  itemCount: items.length,
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    settings: const RouteSettings(
                        name: '/app/page/collection-details'),
                    builder: (_) =>
                        CollectionDetailsScreen(collection: collection),
                  )),
                  onShuffle: () =>
                      _startRandomFromCollection(context, collection),
                );
              },
            ),
    );
  }

  List<MediaItem> _itemsFor(MediaCollection collection) {
    final byId = <String, MediaItem>{
      for (final item in AppController.instance.library) item.id: item
    };
    return collection.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList();
  }
}

class DiscoveryPlaylistsScreen extends StatelessWidget {
  const DiscoveryPlaylistsScreen({super.key});

  static const Map<String, List<String>> _themes = {
    'Halloween Movies & Episodes': [
      'halloween',
      'haunted',
      'spooky',
      'scary',
      'horror',
      'ghost',
      'witch',
      'monster'
    ],
    'Marvel Collection Mix': [
      'marvel',
      'avengers',
      'iron man',
      'captain america',
      'thor',
      'spider-man'
    ],
    'Romance Collection Mix': [
      'romance',
      'romantic',
      'love story',
      'dating',
      'relationship'
    ],
    'Family Collection Mix': [
      'family',
      'kids',
      'children',
      'animated',
      'animation'
    ],
    'Comedy Collection Mix': ['comedy', 'sitcom', 'funny', 'humor', 'stand-up'],
    'Action Movie Mix': [
      'action',
      'adventure',
      'thriller',
      'spy',
      'martial arts'
    ],
  };

  List<MediaCollection> _collectionsFor(List<MediaCollection> collections,
      List<MediaItem> library, List<String> keywords) {
    final byId = <String, MediaItem>{for (final item in library) item.id: item};
    return collections.where((collection) {
      final members =
          collection.mediaIds.map((id) => byId[id]).whereType<MediaItem>();
      final text = <String>[
        collection.name,
        collection.description,
        ...members.expand((m) =>
            <String>[m.title, m.description ?? '', ...m.genres, ...m.tags]),
      ].join(' ').toLowerCase();
      return keywords.any((keyword) => text.contains(keyword));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final collections = AppController.instance.collections;
    final library = AppController.instance.library;
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
          title: const UniversalText('Playlists'),
          backgroundColor: const Color(0xFF090909)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          const Text('Playlists are collections of collections',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Choose a theme to discover its collections. Choosing a collection shuffles to a title or episode inside it.',
              style: TextStyle(color: Colors.white60, height: 1.4)),
          const SizedBox(height: 18),
          _PlaylistThemeCard(
            name: 'All Collections',
            subtitle: '${collections.length} collections • browse everything',
            icon: Icons.collections_bookmark_rounded,
            count: collections.length,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DiscoveryAllCollectionsScreen())),
          ),
          const SizedBox(height: 12),
          for (final entry in _themes.entries) ...[
            Builder(builder: (context) {
              final matchedCollections =
                  _collectionsFor(collections, library, entry.value);
              final virtualCollection = matchedCollections.isEmpty
                  ? _makeVirtualThemeCollection(
                      themeTitle: entry.key,
                      keywords: entry.value,
                      library: library)
                  : null;
              final matches = matchedCollections.isNotEmpty
                  ? matchedCollections
                  : <MediaCollection>[
                      if (virtualCollection != null) virtualCollection
                    ];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlaylistThemeCard(
                  name: entry.key,
                  subtitle: matches.isEmpty
                      ? 'No matching titles yet • add tags or themed episodes'
                      : '${matches.length} ${matches.length == 1 ? 'collection' : 'collections'}${virtualCollection != null ? ' • auto-curated' : ''}',
                  icon: _themeIcon(entry.key),
                  count: matches.length,
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    settings: RouteSettings(
                        name: '/app/page/playlist/${_slug(entry.key)}'),
                    builder: (_) => CollectionPlaylistScreen(
                        title: entry.key, collections: matches),
                  )),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static IconData _themeIcon(String name) {
    if (name.startsWith('Halloween')) return Icons.nights_stay_rounded;
    if (name.startsWith('Marvel')) return Icons.shield_rounded;
    if (name.startsWith('Romance')) return Icons.favorite_rounded;
    if (name.startsWith('Family')) return Icons.family_restroom_rounded;
    if (name.startsWith('Comedy')) return Icons.theater_comedy_rounded;
    return Icons.bolt_rounded;
  }

  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

class CollectionPlaylistScreen extends StatelessWidget {
  final String title;
  final List<MediaCollection> collections;

  const CollectionPlaylistScreen(
      {super.key, required this.title, required this.collections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar:
          AppBar(title: Text(title), backgroundColor: const Color(0xFF090909)),
      body: collections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.playlist_add_rounded,
                      size: 42, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text('No collections match "$title" yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                      'Add a collection with titles or tags related to this theme. It will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60)),
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final collection = collections[index];
                final items = _itemsFor(collection);
                return _CollectionListTile(
                  collection: collection,
                  itemCount: items.length,
                  onTap: () => _startRandomFromCollection(context, collection),
                  onShuffle: () =>
                      _startRandomFromCollection(context, collection),
                );
              },
            ),
    );
  }

  List<MediaItem> _itemsFor(MediaCollection collection) {
    final byId = <String, MediaItem>{
      for (final item in AppController.instance.library) item.id: item
    };
    return collection.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList(growable: false);
  }
}

class _RandomCollectionPick {
  final MediaItem media;
  final MediaItem parent;

  const _RandomCollectionPick({required this.media, required this.parent});
}

void _startRandomFromCollection(
    BuildContext context, MediaCollection collection) {
  final byId = <String, MediaItem>{
    for (final media in AppController.instance.library) media.id: media
  };
  final parents =
      collection.mediaIds.map((id) => byId[id]).whereType<MediaItem>().toList();
  final candidates = <_RandomCollectionPick>[];

  for (final parent in parents) {
    final episodeChoices = <MediaItem>[];
    for (final season in parent.seasons) {
      final rawEpisodes = season['episodes'];
      if (rawEpisodes is! List) continue;
      for (final rawEpisode in rawEpisodes) {
        if (rawEpisode is! Map) continue;
        final episode = Map<String, dynamic>.from(rawEpisode);
        final id = episode['id']?.toString();
        final title = (episode['title'] ?? episode['name'])?.toString();
        if (id == null ||
            id.trim().isEmpty ||
            title == null ||
            title.trim().isEmpty) {
          continue;
        }
        episodeChoices.add(MediaItem(
          id: id,
          title: title,
          type: 'episode',
          imageUrl:
              (episode['imageUrl'] ?? episode['posterUrl'] ?? parent.imageUrl)
                  ?.toString(),
          description: episode['description']?.toString(),
          releaseYear: int.tryParse(
              (episode['releaseYear'] ?? episode['year'] ?? '').toString()),
          playbackUrl:
              (episode['playbackUrl'] ?? episode['streamingUrl'])?.toString(),
          trailerUrl: episode['trailerUrl']?.toString(),
        ));
      }
    }
    if (episodeChoices.isNotEmpty) {
      episodeChoices.shuffle(Random());
      candidates.add(
          _RandomCollectionPick(media: episodeChoices.first, parent: parent));
    } else {
      candidates.add(_RandomCollectionPick(media: parent, parent: parent));
    }
  }

  if (candidates.isEmpty) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/page/collection-details'),
      builder: (_) => CollectionDetailsScreen(collection: collection),
    ));
    return;
  }

  candidates.shuffle(Random());
  final pick = candidates.first;
  final hasStream = pick.media.playbackUrl?.trim().isNotEmpty == true;
  if (hasStream) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/player'),
      builder: (_) => PlayerScreen(
        media: pick.media,
        activityLabel: pick.media.type.toLowerCase() == 'episode'
            ? 'Watching ${pick.parent.title}: ${pick.media.title}'
            : 'Shuffled from ${collection.name}',
      ),
    ));
    return;
  }

  // A random title is still selected; when a usable stream URL is not available,
  // keep the normal detail/play flow rather than opening an empty player.
  Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/app/details'),
    builder: (_) => MediaDetailsScreen(media: pick.parent),
  ));
}

class _DiscoverySectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _DiscoverySectionHeader(
      {required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
        child: Row(
          children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class _DiscoveryMediaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final double width;
  final bool posterOnly;
  final bool? isOwned;

  const _DiscoveryMediaCard(
      {required this.title,
      required this.subtitle,
      required this.imageUrl,
      required this.onTap,
      this.width = 148,
      this.posterOnly = false,
      this.isOwned});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  if (imageUrl?.trim().isNotEmpty == true)
                    Image.network(imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _mediaFallback())
                  else
                    _mediaFallback(),
                  if (!posterOnly)
                    const Positioned(
                        right: 8,
                        bottom: 8,
                        child: Icon(Icons.play_circle_fill_rounded,
                            size: 27, color: Colors.white)),
                  if (isOwned != null)
                    Positioned(
                      left: 7,
                      top: 7,
                      child: RecommendationOwnershipBadge(
                        isOwned: isOwned!,
                        compact: true,
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 2),
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              if (!posterOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 0, 9, 8),
                  child: Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10)),
                )
              else
                const SizedBox(height: 7),
            ]),
          ),
        ),
      );

  Widget _mediaFallback() => const ColoredBox(
      color: Color(0xFF252433),
      child: Center(
          child: Icon(Icons.movie_outlined, size: 34, color: Colors.white24)));
}

class _SearchPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SearchPill({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: const Icon(Icons.search_rounded, size: 17),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.white.withValues(alpha: .06),
        side: BorderSide(color: Colors.white.withValues(alpha: .09)),
        labelStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      );
}

class _FeaturedDiscoveryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _FeaturedDiscoveryCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 225,
        child: Material(
          color: _discoveryPanel,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                        color: _discoveryAccent.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: _discoveryAccent, size: 24)),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                    ])),
              ]),
            ),
          ),
        ),
      );
}

class _CollectionSearchCard extends StatelessWidget {
  final MediaCollection collection;
  final String? imageUrl;
  final VoidCallback onTap;
  const _CollectionSearchCard(
      {required this.collection, required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Material(
          color: _discoveryPanel,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              if (imageUrl?.trim().isNotEmpty == true)
                Image.network(imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback())
              else
                _fallback(),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .95)
                  ]))),
              Positioned(
                  left: 12,
                  right: 12,
                  bottom: 11,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(collection.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text('${collection.mediaIds.length} titles',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ])),
            ]),
          ),
        ),
      );

  Widget _fallback() => const ColoredBox(
      color: Color(0xFF292538),
      child: Center(
          child: Icon(Icons.collections_bookmark_rounded,
              size: 38, color: Colors.white24)));
}

class _PlaylistThemeCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _PlaylistThemeCard(
      {required this.name,
      required this.subtitle,
      required this.icon,
      required this.count,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _discoveryPanel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: _discoveryAccent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: _discoveryAccent, size: 25)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ])),
              if (count > 0)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text('$count',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800))),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ]),
          ),
        ),
      );
}

class _CollectionListTile extends StatelessWidget {
  final MediaCollection collection;
  final int itemCount;
  final VoidCallback onTap;
  final VoidCallback onShuffle;

  const _CollectionListTile(
      {required this.collection,
      required this.itemCount,
      required this.onTap,
      required this.onShuffle});

  @override
  Widget build(BuildContext context) => Material(
        color: _discoveryPanel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                  width: 58,
                  height: 72,
                  decoration: BoxDecoration(
                      color: _discoveryAccent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.collections_bookmark_rounded,
                      size: 28, color: _discoveryAccent)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(collection.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                        collection.description.isEmpty
                            ? '$itemCount titles'
                            : collection.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text('$itemCount ${itemCount == 1 ? 'title' : 'titles'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ])),
              IconButton(
                  tooltip: 'Shuffle and play',
                  onPressed: itemCount == 0 ? null : onShuffle,
                  icon: const Icon(Icons.shuffle_rounded, color: Colors.white)),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ]),
          ),
        ),
      );
}
