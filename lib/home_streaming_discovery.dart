// FILE: lib/home_streaming_discovery.dart
// Purpose: Streaming-style Home discovery, curated collections, and playlist-of-collections flows.

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'app_core.dart';
import 'cinematic_title.dart';
import 'artwork_selection_store.dart';
import 'artwork_gallery_screen.dart';
import 'catalog_poster_image.dart' show CatalogPosterImage, AlbumArtworkImage;
import 'cinematic_discovery_studio.dart';
import 'collection_details.dart';
import 'library_view_modes.dart';
import 'media_metadata_catalog_screen.dart';
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
import 'media_artwork_auto_resolver.dart';
import 'page_hero_banner.dart';

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

/// Shared home-only hover target. Home rail cards publish their hovered item and
/// the hero surfaces it immediately; leaving the card returns to normal rotation.
class HomeHoverPreviewStore {
  HomeHoverPreviewStore._();

  static final ValueNotifier<MediaItem?> current = ValueNotifier<MediaItem?>(null);

  static void show(MediaItem item) => current.value = item;

  static void clear(String mediaId) {
    if (current.value?.id == mediaId) current.value = null;
  }
}

/// Large landscape Home banner with automatic rotation, hover previews and controls.
class HomeHeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  /// Always opens the selected media's details page.
  final ValueChanged<MediaItem> onOpen;
  /// Opens playback; defaults to [onOpen] only for callers that do not provide it.
  final ValueChanged<MediaItem>? onPlay;
  /// Stable settings key: home, movies, or series.
  final String settingsKey;

  const HomeHeroCarousel({
    super.key,
    required this.items,
    required this.onOpen,
    this.onPlay,
    this.settingsKey = 'home',
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
  MediaItem? _hoveredMedia;
  VideoPlayerController? _previewController;
  YoutubePlayerController? _youtubePreviewController;
  StreamSubscription<dynamic>? _youtubePreviewStateSubscription;
  bool _previewMuted = true;
  bool _heroPointerInside = false;
  PageHeroSettings _heroSettings = const PageHeroSettings();

  List<MediaItem> get _items {
    if (!_heroSettings.enabled || widget.items.isEmpty) return const <MediaItem>[];
    final count = min(widget.items.length, _heroSettings.itemCount);
    return widget.items.take(count).toList(growable: false);
  }
  String? _previewUrl;
  String? _youtubePreviewUrl;
  String? _youtubePreviewId;
  final Map<String, String> _tmdbOverviewsByMediaId = <String, String>{};
  final Map<String, int> _tmdbSeasonCountsByMediaId = <String, int>{};
  final Map<String, String> _tmdbYearLabelsByMediaId = <String, String>{};
  final Map<String, String> _musicVideoUrlByMediaId = <String, String>{};
  final Map<String, String> _tmdbTrailerUrlByMediaId = <String, String>{};
  final Set<String> _musicVideoLookupStarted = <String>{};
  final Set<String> _overviewLookupStarted = <String>{};
  final Map<String, String> _selectedBackdropPaths = <String, String>{};
  final Map<String, String> _selectedPosterPaths = <String, String>{};
  final Map<String, String> _automaticBackdropPaths = <String, String>{};
  final Map<String, String> _automaticPosterUrls = <String, String>{};
  final Set<String> _automaticArtworkLookupStarted = <String>{};
  bool _openingHeroArtworkGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeHoverPreviewStore.current.addListener(_onHomeHoverChanged);
    _hoveredMedia = HomeHoverPreviewStore.current.value;
    ArtworkSelectionStore.revision.addListener(_onArtworkSelectionsChanged);
    PageHeroSettingsStore.revision.addListener(_onHeroSettingsChanged);
    unawaited(_loadHeroSettings());
    unawaited(_refreshSelectedBackdrops());
    if (_items.isNotEmpty) {
      final initial = _hoveredMedia ?? _items.first;
      _loadPreview(initial);
      unawaited(_loadOverview(initial));
      unawaited(_loadAutomaticArtwork(initial));
    }
    _scheduleNext();
  }

  Future<void> _loadHeroSettings() async {
    final loaded = await PageHeroSettingsStore.load(widget.settingsKey);
    if (!mounted) return;
    setState(() {
      _heroSettings = loaded;
      if (!loaded.audioEnabled) _previewMuted = true;
    });
    _scheduleNext();
    if (!loaded.enabled || !loaded.audioEnabled) {
      await _applyCurrentAudioPolicy();
    }
  }

  void _onHeroSettingsChanged() {
    unawaited(_loadHeroSettings());
  }

  Future<void> _applyCurrentAudioPolicy() async {
    final youtube = _youtubePreviewController;
    if (youtube != null) await _applyYoutubePreviewAudio(youtube);
    final direct = _previewController;
    if (direct != null && direct.value.isInitialized) {
      try {
        await direct.setVolume(_heroSettings.audioEnabled && !_previewMuted ? 1 : 0);
      } catch (_) {}
    }
  }

  void _onHomeHoverChanged() {
    if (!mounted) return;
    final next = HomeHoverPreviewStore.current.value;
    if (_hoveredMedia?.id == next?.id) return;
    setState(() => _hoveredMedia = next);
    if (next != null) {
      _loadPreview(next);
      unawaited(_loadOverview(next));
      unawaited(_loadAutomaticArtwork(next));
    } else if (_items.isNotEmpty) {
      final current = _items[_index.clamp(0, _items.length - 1).toInt()];
      _loadPreview(current);
      unawaited(_loadOverview(current));
      unawaited(_loadAutomaticArtwork(current));
    }
    // Hover previews must not cancel carousel rotation permanently. The timer
    // keeps advancing and is restarted by each page change or manual action.
    _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant HomeHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemCountChanged = oldWidget.items.length != widget.items.length;
    if (_items.isEmpty || _index >= _items.length) {
      _index = 0;
      if (_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients && _items.isNotEmpty) {
            _pageController.jumpToPage(0);
          }
        });
      }
    }
    if (itemCountChanged) _scheduleNext();
    if (oldWidget.settingsKey != widget.settingsKey) unawaited(_loadHeroSettings());
    unawaited(_refreshSelectedBackdrops());
    if (_items.isNotEmpty) {
      unawaited(_loadOverview(_items[_index]));
      unawaited(_loadPreview(_items[_index]));
      unawaited(_loadAutomaticArtwork(_items[_index]));
    }
  }

  void _onArtworkSelectionsChanged() {
    unawaited(_refreshSelectedBackdrops());
  }

  Future<void> _refreshSelectedBackdrops() async {
    final profileId = AppController.instance.currentProfile?.id ?? 'guest';
    final nextBackdrops = <String, String>{};
    final nextPosters = <String, String>{};
    final automaticBackdrops = <String, String>{};
    final automaticPosters = <String, String>{};
    for (final item in _items) {
      final paths = await Future.wait<String?>(<Future<String?>>[
        ArtworkSelectionStore.readBackdropPath(
          profileId: profileId,
          mediaId: item.id,
        ),
        ArtworkSelectionStore.readPosterPath(
          profileId: profileId,
          mediaId: item.id,
        ),
        MediaArtworkAutoResolver.readAutoBackdropPath(item.id),
        MediaArtworkAutoResolver.readAutoPosterUrl(item.id),
      ]);
      final backdrop = paths[0];
      final poster = paths[1];
      final automaticBackdrop = paths[2];
      final automaticPoster = paths[3];
      if (backdrop != null && backdrop.isNotEmpty) {
        nextBackdrops[item.id] = backdrop;
      }
      if (poster != null && poster.isNotEmpty) nextPosters[item.id] = poster;
      if ((backdrop == null || backdrop.isEmpty) &&
          automaticBackdrop != null && automaticBackdrop.isNotEmpty) {
        automaticBackdrops[item.id] = automaticBackdrop;
      }
      if ((poster == null || poster.isEmpty) &&
          automaticPoster != null && automaticPoster.isNotEmpty) {
        automaticPosters[item.id] = automaticPoster;
      }
    }
    if (!mounted) return;
    final changed = _mapsDiffer(nextBackdrops, _selectedBackdropPaths) ||
        _mapsDiffer(nextPosters, _selectedPosterPaths) ||
        _mapsDiffer(automaticBackdrops, _automaticBackdropPaths) ||
        _mapsDiffer(automaticPosters, _automaticPosterUrls);
    if (changed) {
      setState(() {
        _selectedBackdropPaths
          ..clear()
          ..addAll(nextBackdrops);
        _selectedPosterPaths
          ..clear()
          ..addAll(nextPosters);
        _automaticBackdropPaths
          ..clear()
          ..addAll(automaticBackdrops);
        _automaticPosterUrls
          ..clear()
          ..addAll(automaticPosters);
      });
    }
  }

  bool _mapsDiffer(Map<String, String> next, Map<String, String> current) =>
      next.length != current.length ||
      next.entries.any((entry) => current[entry.key] != entry.value);

  Future<void> _loadAutomaticArtwork(MediaItem media) async {
    if (!CinematicTitleMetadataService.isConfigured ||
        !_automaticArtworkLookupStarted.add(media.id)) {
      return;
    }
    try {
      final result = await MediaArtworkAutoResolver.resolveMedia(media);
      if (result == null) return;
      await MediaArtworkAutoResolver.rememberResolvedArtwork(media, result);
      final profileId = AppController.instance.currentProfile?.id ?? 'guest';
      final selections = await Future.wait<String?>(<Future<String?>>[
        ArtworkSelectionStore.readBackdropPath(
          profileId: profileId,
          mediaId: media.id,
        ),
        ArtworkSelectionStore.readPosterPath(
          profileId: profileId,
          mediaId: media.id,
        ),
        MediaArtworkAutoResolver.readAutoBackdropPath(media.id),
        MediaArtworkAutoResolver.readAutoPosterUrl(media.id),
      ]);
      if (!mounted) return;
      setState(() {
        final customBackdrop = selections[0];
        final customPoster = selections[1];
        final autoBackdrop = selections[2];
        final autoPoster = selections[3];
        if (customBackdrop?.isNotEmpty == true) {
          _selectedBackdropPaths[media.id] = customBackdrop!;
          _automaticBackdropPaths.remove(media.id);
        } else if (autoBackdrop?.isNotEmpty == true) {
          _automaticBackdropPaths[media.id] = autoBackdrop!;
        } else if (result.backdropPath?.trim().isNotEmpty == true) {
          _automaticBackdropPaths[media.id] = result.backdropPath!.trim();
        }
        if (customPoster?.isNotEmpty == true) {
          _selectedPosterPaths[media.id] = customPoster!;
          _automaticPosterUrls.remove(media.id);
        } else if (autoPoster?.isNotEmpty == true) {
          _automaticPosterUrls[media.id] = autoPoster!;
        } else if (result.posterUrl?.trim().isNotEmpty == true) {
          // Keep provider artwork as a fallback even when the catalog already
          // has an image URL; the existing URL may be stale or inaccessible.
          _automaticPosterUrls[media.id] = result.posterUrl!.trim();
        }
      });
    } catch (_) {
      // Automatic artwork is a best-effort enhancement; keep the catalog usable.
    }
  }

  Future<void> _openHeroArtworkGallery(MediaItem media) async {
    if (!_isMovieOrShow(media) || _openingHeroArtworkGallery) return;
    if (!CinematicTitleMetadataService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connect and start the metadata backend to browse poster and backdrop choices.'),
      ));
      return;
    }
    setState(() => _openingHeroArtworkGallery = true);
    try {
      final metadata = await CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: media.isSeries || _isTvMedia(media),
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (!mounted) return;
      if (metadata == null ||
          (metadata.posterPaths.isEmpty && metadata.backdropPaths.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No poster or backdrop gallery found for "${media.title}".'),
        ));
        return;
      }
      final profileId = AppController.instance.currentProfile?.id ?? 'guest';
      final savedPoster = await ArtworkSelectionStore.readPosterPath(
        profileId: profileId,
        mediaId: media.id,
      );
      final savedBackdrop = await ArtworkSelectionStore.readBackdropPath(
        profileId: profileId,
        mediaId: media.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ArtworkGalleryScreen(
            media: media,
            metadata: metadata,
            initialPosterPath: savedPoster ?? metadata.posterPath,
            initialBackdropPath: savedBackdrop ?? metadata.backdropPath,
            onPosterSet: (path) {
              if (!mounted) return;
              setState(() => _selectedPosterPaths[media.id] = path);
            },
            onBackdropSet: (path) {
              if (!mounted) return;
              setState(() => _selectedBackdropPaths[media.id] = path);
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open artwork gallery: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingHeroArtworkGallery = false);
    }
  }

  bool _isTvMedia(MediaItem media) {
    final type = media.type.trim().toLowerCase();
    return media.isSeries ||
        type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show' ||
        type == 'series' ||
        type.contains('series') ||
        type == 'television' ||
        type == 'episode';
  }

  bool _isMovieOrShow(MediaItem media) =>
      MediaArtworkAutoResolver.isMovieOrShow(media) || _isTvMedia(media);

  Future<void> _loadOverview(MediaItem media) async {
    unawaited(_loadAutomaticArtwork(media));
    if (!_isMovieOrShow(media) ||
        !CinematicTitleMetadataService.isConfigured ||
        !_overviewLookupStarted.add(media.id)) {
      return;
    }
    try {
      final metadata = await CinematicTitleMetadataService.lookupHomeMetadata(
        title: media.title,
        isTv: media.isSeries || _isTvMedia(media),
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (!mounted || metadata == null) return;
      final overview = metadata['overview']?.toString().trim() ?? '';
      final seasonCount = metadata['seasonCount'] is int
          ? metadata['seasonCount'] as int
          : int.tryParse(metadata['seasonCount']?.toString() ?? '');
      final yearLabel = metadata['yearLabel']?.toString().trim() ?? '';
      final previewUrl = metadata['previewUrl']?.toString().trim() ?? '';
      if (previewUrl.isNotEmpty &&
          media.trailerUrl?.trim().isNotEmpty != true &&
          _extractYoutubeVideoId(previewUrl) != null) {
        _tmdbTrailerUrlByMediaId[media.id] = previewUrl;
      }
      setState(() {
        if (overview.isNotEmpty) {
          _tmdbOverviewsByMediaId[media.id] = overview;
        }
        if ((media.isSeries || _isTvMedia(media)) && seasonCount != null && seasonCount > 0) {
          _tmdbSeasonCountsByMediaId[media.id] = seasonCount;
        }
        if (media.isSeries && yearLabel.isNotEmpty) {
          _tmdbYearLabelsByMediaId[media.id] = yearLabel;
        }
      });
      final isSelected = _hoveredMedia?.id == media.id ||
          (_items.isNotEmpty &&
              _items[_index.clamp(0, _items.length - 1).toInt()].id == media.id);
      if (previewUrl.isNotEmpty &&
          media.trailerUrl?.trim().isNotEmpty != true &&
          _extractYoutubeVideoId(previewUrl) != null &&
          isSelected) {
        unawaited(_loadPreview(media));
      }
    } catch (_) {
      // Metadata lookups are best-effort; keep local catalog values on error.
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
      final youtubeController = _youtubePreviewController;
      if (youtubeController != null) {
        if (_previewMuted) {
          youtubeController.mute();
        } else {
          youtubeController.unMute();
        }
        youtubeController.playVideo();
      }
    } else {
      _advanceTimer?.cancel();
      _advanceTimer = null;
      _previewController?.pause();
      _youtubePreviewController?.pauseVideo();
    }
  }

  String? _extractYoutubeVideoId(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    String? candidate;
    if (uri.host == 'youtu.be' || uri.host == 'www.youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (const <String>{'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com'}.contains(uri.host)) {
      if (uri.path == '/watch') {
        candidate = uri.queryParameters['v'];
      } else if (uri.pathSegments.length >= 2 &&
          const <String>{'shorts', 'embed', 'live', 'v'}.contains(uri.pathSegments.first)) {
        candidate = uri.pathSegments[1];
      }
    }
    if (candidate == null) return null;
    final cleaned = candidate.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(cleaned) ? cleaned : null;
  }

  Future<void> _disposeDirectPreview() async {
    final old = _previewController;
    _previewController = null;
    _previewUrl = null;
    if (old != null) {
      await old.pause();
      await old.dispose();
    }
  }

  void _disposeYoutubePreview() {
    final subscription = _youtubePreviewStateSubscription;
    _youtubePreviewStateSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());

    final old = _youtubePreviewController;
    _youtubePreviewController = null;
    _youtubePreviewUrl = null;
    _youtubePreviewId = null;
    old?.close();
  }

  Future<void> _toggleHeroPreviewAudio(MediaItem media) async {
    if (!_heroSettings.audioEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hero preview audio is disabled in Customize App.'),
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }
    final nextMuted = !_previewMuted;
    if (mounted) setState(() => _previewMuted = nextMuted);

    final previewUrl = _effectivePreviewUrl(media);
    final youtube = _youtubePreviewController;
    if (youtube != null && _youtubePreviewUrl == previewUrl) {
      // A tap is a direct user gesture. Apply the requested state now, and
      // the controller's readiness listener below retries if its iframe has
      // not finished initializing yet.
      await _applyYoutubePreviewAudio(youtube);
      if (!nextMuted) {
        try {
          await youtube.playVideo();
        } catch (_) {
          // Readiness listener will start playback after the iframe is ready.
        }
      }
      return;
    }

    final direct = _previewController;
    if (direct != null && _previewUrl == previewUrl) {
      // If direct video initialization is still in progress, _loadPreview
      // applies the latest _previewMuted state as soon as initialization ends.
      try {
        if (direct.value.isInitialized) {
          await direct.setVolume(_heroSettings.audioEnabled && !nextMuted ? 1 : 0);
          if (!nextMuted) await direct.play();
        }
      } catch (_) {
        // Keep the selected state; controller initialization will retry it.
      }
      return;
    }

    if (previewUrl?.trim().isNotEmpty == true) {
      await _loadPreview(media);
      return;
    }

    // Music entries can resolve a preview asynchronously through the backend.
    // Wait for that lookup before telling the user there is nothing to unmute.
    if (_isMusicVideoSearchable(media)) {
      await _findMusicVideoPreview(media);
      if (_effectivePreviewUrl(media)?.trim().isNotEmpty == true) {
        await _loadPreview(media);
        return;
      }
    } else {
      await _loadPreview(media);
    }

    if (_effectivePreviewUrl(media)?.trim().isNotEmpty != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('There is no video/audio preview available for this title yet.'),
        duration: Duration(seconds: 3),
      ));
    }
  }

  Future<void> _applyYoutubePreviewAudio(
    YoutubePlayerController controller,
  ) async {
    try {
      if (!_heroSettings.audioEnabled || _previewMuted) {
        await controller.mute();
        await controller.setVolume(0);
      } else {
        await controller.unMute();
        await controller.setVolume(100);
      }
    } catch (_) {
      // The iframe can briefly be unavailable while a new video is loading.
      // The desired state remains in _previewMuted and is applied again when
      // the same preview is reused or the user presses the audio control.
    }
  }

  String? _effectivePreviewUrl(MediaItem media) {
    final explicit = media.trailerUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _musicVideoUrlByMediaId[media.id] ?? _tmdbTrailerUrlByMediaId[media.id];
  }

  bool _isMusicVideoSearchable(MediaItem media) {
    final type = media.type.trim().toLowerCase();
    return type == 'song' ||
        type == 'track' ||
        type.contains('track') ||
        type == 'audio' ||
        type == 'music' ||
        type == 'album' ||
        type == 'soundtrack' ||
        type == 'musicrelease' ||
        type == 'music release' ||
        type.contains('album');
  }

  Future<void> _findMusicVideoPreview(MediaItem media) async {
    if (!_isMusicVideoSearchable(media) ||
        !AppController.instance.isBackendAuthenticated ||
        !_musicVideoLookupStarted.add(media.id)) {
      return;
    }

    final creditedArtists = media.music.take(3).join(' ');
    final query = '${media.title} $creditedArtists official music video'.trim();
    try {
      final payload = await AppController.instance.backendApi.searchMusicVideos(
        query,
        limit: 1,
      );
      final rawItems = payload['items'];
      if (rawItems is! List || rawItems.isEmpty || rawItems.first is! Map) {
        return;
      }
      final item = Map<String, dynamic>.from(rawItems.first as Map);
      final videoId = item['videoId']?.toString().trim();
      final watchUrl = item['watchUrl']?.toString().trim();
      final url = videoId != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)
          ? 'https://www.youtube.com/watch?v=$videoId'
          : watchUrl;
      if (url == null || !url.startsWith('http')) return;
      _musicVideoUrlByMediaId[media.id] = url;

      // A slow response for a card that is no longer hovered must not replace
      // the newer title's active preview. The result remains cached for next time.
      final stillSelected = _hoveredMedia?.id == media.id ||
          (_items.isNotEmpty &&
              _items[_index.clamp(0, _items.length - 1).toInt()].id == media.id);
      if (mounted && stillSelected) await _loadPreview(media);
    } catch (_) {
      // Keep Home usable when the backend or YouTube search is unavailable.
    }
  }

  Future<void> _loadPreview(MediaItem media) async {
    final url = _effectivePreviewUrl(media);
    if ((url == null || url.isEmpty) && _isMusicVideoSearchable(media)) {
      unawaited(_findMusicVideoPreview(media));
    }
    if (url == null || url.isEmpty || !url.startsWith('http')) {
      _disposeYoutubePreview();
      await _disposeDirectPreview();
      if (mounted) setState(() {});
      return;
    }

    final youtubeId = _extractYoutubeVideoId(url);
    if (youtubeId != null) {
      await _disposeDirectPreview();
      if (_youtubePreviewId == youtubeId && _youtubePreviewController != null) {
        unawaited(_applyYoutubePreviewAudio(_youtubePreviewController!));
        _youtubePreviewController!.playVideo();
        if (mounted) setState(() {});
        return;
      }
      _disposeYoutubePreview();
      _youtubePreviewUrl = url;
      _youtubePreviewId = youtubeId;
      final controller = YoutubePlayerController.fromVideoId(
        videoId: youtubeId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          // Hero playback is decorative; do not let the embedded YouTube
          // surface swallow taps intended for the Flutter controls above it.
          pointerEvents: PointerEvents.none,
          mute: true,
          showControls: false,
          showFullscreenButton: false,
          enableCaption: false,
          playsInline: true,
          loop: true,
        ),
      );
      _youtubePreviewController = controller;
      var audioAppliedWhenReady = false;
      _youtubePreviewStateSubscription = controller.stream.listen((value) {
        // youtube_player_iframe 6.x exposes readiness through playerState; unknown means no player state has arrived yet.
        if (value.playerState == PlayerState.unknown || audioAppliedWhenReady) return;
        audioAppliedWhenReady = true;
        if (!identical(_youtubePreviewController, controller)) return;
        unawaited(_applyYoutubePreviewAudio(controller));
        if (!_previewMuted) unawaited(controller.playVideo());
      });
      // Some platforms can report a player state before the first stream event
      // reaches this listener, so also inspect the current controller value once.
      if (controller.value.playerState != PlayerState.unknown) {
        audioAppliedWhenReady = true;
        unawaited(_applyYoutubePreviewAudio(controller));
        if (!_previewMuted) unawaited(controller.playVideo());
      }
      if (mounted) setState(() {});
      return;
    }

    _disposeYoutubePreview();
    if (_previewUrl == url && _previewController?.value.isInitialized == true) {
      await _previewController!.seekTo(Duration.zero);
      await _previewController!.setVolume(_heroSettings.audioEnabled && !_previewMuted ? 1 : 0);
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
      await controller.setVolume(_heroSettings.audioEnabled && !_previewMuted ? 1 : 0);
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
    if (!_appIsActive || _items.length < 2) return;
    _advanceTimer = Timer(Duration(seconds: _heroSettings.intervalSeconds), () async {
      if (!mounted || !_appIsActive || _items.length < 2) return;
      if (!_pageController.hasClients) {
        _scheduleNext();
        return;
      }
      // A shelf hover preview can otherwise sit over the PageView and make
      // the carousel appear frozen. Clear that transient override when the
      // timer advances so the next selected carousel page is visibly shown.
      final hovered = _hoveredMedia;
      if (hovered != null) {
        setState(() => _hoveredMedia = null);
        HomeHoverPreviewStore.clear(hovered.id);
      }
      final next = (_index + 1) % _items.length;
      try {
        await _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        // The Home page or PageController may be rebuilding during settings
        // changes. A missed animation must not permanently stop autoplay.
      }
      if (mounted) _scheduleNext();
    });
  }

  void _move(int delta) {
    if (_items.length < 2) return;
    final hovered = _hoveredMedia;
    if (hovered != null) {
      setState(() => _hoveredMedia = null);
      HomeHoverPreviewStore.clear(hovered.id);
    }
    final next = (_index + delta + _items.length) % _items.length;
    if (!_pageController.hasClients) {
      setState(() => _index = next);
      _loadPreview(_items[next]);
      unawaited(_loadOverview(_items[next]));
      unawaited(_loadAutomaticArtwork(_items[next]));
      _scheduleNext();
      return;
    }
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (!mounted) return;
      if (_index != next) setState(() => _index = next);
      _loadPreview(_items[next]);
      unawaited(_loadOverview(_items[next]));
      unawaited(_loadAutomaticArtwork(_items[next]));
      _scheduleNext();
    }).catchError((Object _) {
      if (mounted) _scheduleNext();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeHoverPreviewStore.current.removeListener(_onHomeHoverChanged);
    ArtworkSelectionStore.revision.removeListener(_onArtworkSelectionsChanged);
    PageHeroSettingsStore.revision.removeListener(_onHeroSettingsChanged);
    _advanceTimer?.cancel();
    _previewController?.dispose();
    _disposeYoutubePreview();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    // On desktop the hero uses roughly the upper half of the window; mobile
    // keeps a shorter banner so the first discovery shelf remains visible.
    final height = width < 600
        ? (width * .72).clamp(300.0, 430.0).toDouble()
        : (width * .43).clamp(420.0, 590.0).toDouble();

    return MouseRegion(
      onEnter: (_) { if (mounted) setState(() => _heroPointerInside = true); },
      onExit: (_) { if (mounted) setState(() => _heroPointerInside = false); },
      child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _move(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _move(1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
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
                itemCount: _items.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  final previewItem = _hoveredMedia ?? _items[value];
                  _loadPreview(previewItem);
                  unawaited(_loadOverview(previewItem));
                  unawaited(_loadAutomaticArtwork(previewItem));
                  _scheduleNext();
                },
                itemBuilder: (context, index) => IgnorePointer(
                  child: _buildHeroPage(_items[index]),
                ),
              ),
              if (_hoveredMedia != null)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<String>('home-hover-${_hoveredMedia!.id}'),
                      child: IgnorePointer(child: _buildHeroPage(_hoveredMedia!)),
                    ),
                  ),
                ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 18,
                child: Builder(builder: (context) {
                  // Keep the indicator compact even if a large library produces
                  // dozens or hundreds of hero items. Arrow keys can reach all.
                  final visibleDots = min(9, _items.length);
                  final firstDot = max(
                    0,
                    min(_index - visibleDots ~/ 2,
                        _items.length - visibleDots),
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(visibleDots, (slot) {
                      final index = firstDot + slot;
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
                  );
                }),
              ),
              ..._buildHeroControls(
                _hoveredMedia ?? _items[_index.clamp(0, _items.length - 1).toInt()],
                compact: width < 600,
              ),
              if (_items.length > 1) ...[
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
                    child: Text('${_index + 1} / ${_items.length}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildHeroPage(MediaItem media) {
    final selectedPosterUrl = CinematicTitleMetadataService.imageUrl(
          _selectedPosterPaths[media.id],
          size: 'w500',
        ) ??
        ((media.imageUrl?.trim().isNotEmpty == true)
            ? media.imageUrl
            : _automaticPosterUrls[media.id]);
    final selectedBackdropUrl = CinematicTitleMetadataService.imageUrl(
          _selectedBackdropPaths[media.id],
          size: 'w1280',
        ) ??
        CinematicTitleMetadataService.imageUrl(
          _automaticBackdropPaths[media.id],
          size: 'w1280',
        );
    Widget posterErrorFallback(BoxFit fit, {Alignment alignment = Alignment.center}) {
      final automaticPoster = _automaticPosterUrls[media.id]?.trim() ?? '';
      if (automaticPoster.isNotEmpty && automaticPoster != selectedPosterUrl) {
        return CachedNetworkImage(
          imageUrl: automaticPoster,
          fit: fit,
          alignment: alignment,
          fadeInDuration: const Duration(milliseconds: 100),
          placeholder: (_, __) => _heroFallback(media),
          errorWidget: (_, __, ___) => _heroFallback(media),
        );
      }
      return _heroFallback(media);
    }
    final tmdbOverview = _tmdbOverviewsByMediaId[media.id]?.trim();
    // Movie/show heroes prefer TMDB's actual overview. Albums and titles without
    // an exact TMDB match fall back to the overview/description in the catalog.
    final description = tmdbOverview?.isNotEmpty == true
        ? tmdbOverview
        : media.description?.trim();
    final heroMetadata = <String>[];
    final localYearLabel = media.displayYearLabel;
    final tmdbYearLabel = _tmdbYearLabelsByMediaId[media.id];
    final localSeriesYearIsPartial = media.isSeries &&
        media.seriesEndYear == null &&
        !media.seriesOngoing &&
        !media.isSeriesUpcoming &&
        (localYearLabel == null || !localYearLabel.contains('–'));
    final yearLabel = localSeriesYearIsPartial && tmdbYearLabel != null
        ? tmdbYearLabel
        : (localYearLabel ?? tmdbYearLabel);
    if (yearLabel != null && yearLabel.isNotEmpty) heroMetadata.add(yearLabel);
    final editionLabel = media.displayEditionLabel;
    if (editionLabel != null && editionLabel.isNotEmpty) {
      heroMetadata.add(editionLabel);
    }
    final seasonCount = media.displaySeasonCount ?? _tmdbSeasonCountsByMediaId[media.id];
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
        if (_heroSettings.artworkMode != 'Posters only' &&
            selectedBackdropUrl != null &&
            !((_previewController != null &&
                  _previewUrl == _effectivePreviewUrl(media) &&
                  _previewController!.value.isInitialized) ||
              (_youtubePreviewController != null &&
                  _youtubePreviewUrl == _effectivePreviewUrl(media))))
          Positioned.fill(
            // Keep the backdrop contained while letting the user choose how
            // strongly it zooms on hover. ClipRRect confines the zoom to the hero.
            child: ClipRect(
              child: AnimatedScale(
                scale: _heroPointerInside ? _heroSettings.hoverScale : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: CachedNetworkImage(
                        imageUrl: selectedBackdropUrl,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: .38),
                        colorBlendMode: BlendMode.darken,
                        fadeInDuration: const Duration(milliseconds: 100),
                        placeholder: (_, __) => _heroFallback(media),
                        errorWidget: (_, __, ___) => _heroFallback(media),
                      ),
                    ),
                    CachedNetworkImage(
                      imageUrl: selectedBackdropUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      fadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _heroFallback(media),
                      errorWidget: (_, __, ___) => _heroFallback(media),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_youtubePreviewController != null &&
            _youtubePreviewUrl == _effectivePreviewUrl(media))
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: YoutubePlayer(
                controller: _youtubePreviewController!,
                aspectRatio: 16 / 9,
              ),
            ),
          )
        else if (_previewController != null &&
            _previewUrl == _effectivePreviewUrl(media) &&
            _previewController!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _previewController!.value.size.width,
              height: _previewController!.value.size.height,
              child: IgnorePointer(
                ignoring: true,
                child: VideoPlayer(_previewController!),
              ),
            ),
          )
        else if (_heroSettings.artworkMode != 'Backdrops only' &&
            selectedPosterUrl?.trim().isNotEmpty == true)
          Positioned.fill(
            child: ClipRect(
              child: AnimatedScale(
                scale: _heroPointerInside ? _heroSettings.hoverScale : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: selectedPosterUrl!,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: .48),
                      colorBlendMode: BlendMode.darken,
                      fadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _heroFallback(media),
                      errorWidget: (_, __, ___) => posterErrorFallback(BoxFit.cover),
                    ),
                    CachedNetworkImage(
                      imageUrl: selectedPosterUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      fadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _heroFallback(media),
                      errorWidget: (_, __, ___) => posterErrorFallback(BoxFit.contain, alignment: Alignment.centerRight),
                    ),
                  ],
                ),
              ),
            ),
          )
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
        Positioned(
          left: 26,
          right: 26,
          bottom: MediaQuery.sizeOf(context).width < 600 ? 82 : 96,
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
                  child: Text(_heroTypeLabel(media),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1)),
                ),
                const SizedBox(height: 10),
                CinematicTitle(
                  media: media,
                  placement: CinematicTitlePlacement.hero,
                  textAlign: TextAlign.start,
                  maxWidth: 720,
                  height: MediaQuery.sizeOf(context).width < 600 ? 76 : 96,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHeroControls(MediaItem media, {required bool compact}) {
    final controls = <Widget>[
      Positioned(
        left: compact ? 18 : 26,
        right: compact ? 108 : 126,
        bottom: compact ? 14 : 28,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilledButton.icon(
              onPressed: () {
                final playbackUrl = media.playbackUrl?.trim() ?? '';
                final trailerUrl = _effectivePreviewUrl(media)?.trim() ?? '';
                final playable = playbackUrl.isEmpty &&
                        media.trailerUrl?.trim().isNotEmpty != true &&
                        trailerUrl.isNotEmpty
                    ? MediaItem.fromJson(<String, dynamic>{
                        ...media.toJson(),
                        'trailerUrl': trailerUrl,
                      })
                    : media;

                // Movies/Shows/Home provide a player callback that can resolve
                // local files and server-side playback by media ID even if a
                // direct playbackUrl hasn't been filled in yet.
                if (widget.onPlay != null) {
                  widget.onPlay!(playable);
                  return;
                }
                if (playbackUrl.isEmpty && trailerUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No playable file or trailer is available for this title yet.'),
                    duration: Duration(seconds: 3),
                  ));
                  return;
                }
                widget.onOpen(playable);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const UniversalText('Play', style: TextStyle(fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 22,
                  vertical: compact ? 9 : 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onOpen(media),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              label: const UniversalText('More info', style: TextStyle(fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: .42),
                side: BorderSide(color: Colors.white.withValues(alpha: .58)),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 18,
                  vertical: compact ? 9 : 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ];
    if (_isMovieOrShow(media)) {
      controls.add(Positioned(
        right: compact ? 62 : 70,
        bottom: compact ? 14 : 28,
        child: Material(
          color: Colors.black.withValues(alpha: .46),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Open artwork gallery',
            onPressed: _openingHeroArtworkGallery
                ? null
                : () => unawaited(_openHeroArtworkGallery(media)),
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
        ),
      ));
    }
    controls.add(Positioned(
      right: compact ? 12 : 20,
      bottom: compact ? 14 : 28,
      child: Material(
        color: Colors.black.withValues(alpha: .46),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: !_heroSettings.audioEnabled
              ? 'Hero preview audio disabled in Customize App'
              : _previewMuted ? 'Turn hero preview sound on' : 'Turn hero preview sound off',
          onPressed: _heroSettings.audioEnabled
              ? () => unawaited(_toggleHeroPreviewAudio(media))
              : null,
          icon: Icon(!_heroSettings.audioEnabled || _previewMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        ),
      ),
    ));
    return controls;
  }

  String _heroTypeLabel(MediaItem media) {
    final raw = media.type.toLowerCase().trim();
    if (media.isSeries || raw.contains('tv') || raw.contains('series') || raw.contains('show')) {
      return 'TV SERIES';
    }
    if (raw.contains('album') || raw == 'soundtrack' || raw == 'musicrelease') {
      return 'ALBUM';
    }
    if (raw == 'track' || raw == 'song' || raw == 'audio' || raw.contains('track')) return 'SONG';
    if (raw == 'artist' || raw == 'musician') return 'MUSIC ARTIST';
    if (raw.contains('movie') || raw.contains('film') || raw == 'feature') return 'MOVIE';
    return raw.isEmpty ? 'FEATURED' : raw.toUpperCase();
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
        color: Colors.black.withValues(alpha: .58),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Icon(icon, size: 31, color: Colors.white),
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
                  media: entry.parent,
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
                media: media,
                isOwned: AppController.instance.isOwned(media.id),
                isWatched: AppController.instance.watched.any((item) => item.id == media.id),
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
        final matches = catalog.values.where((candidate) => candidate.id != seed.id && <String>{...candidate.actors, ...candidate.directors, ...candidate.writers}.any((credit) => _norm(credit) == normalizedPerson)).toList();
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
        _DiscoverySectionHeader(title: 'Because you saw ${shelf.person} in ${shelf.seed.title}', subtitle: 'More titles with this actor, actress, director, or screenwriter; status shows ownership and watch history'),
        HomeArrowRail(height: 210, itemCount: shelf.items.length, separatorExtent: 12, padding: const EdgeInsets.symmetric(horizontal: 48), itemBuilder: (context, index) {
          final media = shelf.items[index];
          return _DiscoveryMediaCard(title: media.title, subtitle: '${media.displayYearLabel ?? ''} ${media.type}'.trim(), imageUrl: media.imageUrl, media: media, isOwned: controller.isOwned(media.id), isWatched: controller.watched.any((item) => item.id == media.id), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: '/app/details'), builder: (_) => MediaDetailsScreen(media: media))));
        }),
      ],
    ]);
  }
}

bool _isMovieOrShowForRecommendation(MediaItem? item) {
  if (item == null || isExcludedEntertainmentType(item.type)) return false;
  final type = item.type.trim().toLowerCase();
  return item.isSeries || type == 'movie' || type == 'film' || type == 'feature' ||
      type.contains('movie') || type.contains('film') || type.contains('tv') ||
      type.contains('show') || type.contains('series');
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
    for (final item in <MediaItem>[...library, ...controller.recommendations, ...controller.watched, ...controller.liked]) {
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
                media: media,
                isOwned: AppController.instance.isOwned(media.id),
                isWatched: AppController.instance.watched.any((item) => item.id == media.id),
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
    final watchedTitles = visibleWatched
        .where(_isMovieOrShowForRecommendation)
        .toList(growable: false);
    final watchedSeed = watchedTitles.isEmpty ? null : watchedTitles.last;
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
        _related(watchedSeed),
      ));
    }
    final controller = AppController.instance;
    final likedTitles = controller.liked.where(_isMovieOrShowForRecommendation).toList(growable: false);
    final likedSeed = likedTitles.isEmpty ? null : likedTitles.last;
    if (likedSeed != null) {
      children.add(_mediaShelf(
        context,
        'Because you liked “${likedSeed.title}”',
        'Related titles across your library, watched history, and catalog picks',
        _related(likedSeed),
      ));
    }
    if (watchedSeed != null || likedSeed != null) {
      children.add(_HomeExternalTitleRecommendationShelves(
        watchedSeed: _isMovieOrShowForRecommendation(watchedSeed) ? watchedSeed : null,
        likedSeed: likedSeed,
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

class _HomeExternalTitleRecommendationShelves extends StatefulWidget {
  const _HomeExternalTitleRecommendationShelves({
    required this.watchedSeed,
    required this.likedSeed,
  });

  final MediaItem? watchedSeed;
  final MediaItem? likedSeed;

  @override
  State<_HomeExternalTitleRecommendationShelves> createState() =>
      _HomeExternalTitleRecommendationShelvesState();
}

class _HomeExternalTitleRecommendationShelvesState
    extends State<_HomeExternalTitleRecommendationShelves> {
  final Map<String, List<CinematicTitleRecommendation>> _recommendations =
      <String, List<CinematicTitleRecommendation>>{};
  final Set<String> _loading = <String>{};
  final Set<String> _started = <String>{};

  String _key(String reason, MediaItem media) => '$reason:${media.id}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentSeeds());
  }

  @override
  void didUpdateWidget(covariant _HomeExternalTitleRecommendationShelves oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchedSeed?.id != widget.watchedSeed?.id ||
        oldWidget.likedSeed?.id != widget.likedSeed?.id) {
      unawaited(_loadCurrentSeeds());
    }
  }

  Future<void> _loadCurrentSeeds() async {
    if (!CinematicTitleMetadataService.isConfigured) return;
    final seeds = <({String reason, MediaItem media})>[
      if (widget.watchedSeed != null)
        (reason: 'watched', media: widget.watchedSeed!),
      if (widget.likedSeed != null)
        (reason: 'liked', media: widget.likedSeed!),
    ];
    for (final seed in seeds) {
      final key = _key(seed.reason, seed.media);
      if (!_started.add(key)) continue;
      if (mounted) setState(() => _loading.add(key));
      try {
        final metadata = await CinematicTitleMetadataService.lookupTitle(
          title: seed.media.title,
          isTv: seed.media.isSeries,
          year: seed.media.releaseYear ?? seed.media.seriesStartYear,
        );
        if (metadata == null) {
          if (mounted) setState(() => _recommendations[key] = const <CinematicTitleRecommendation>[]);
          continue;
        }
        final fetched = await CinematicTitleMetadataService.lookupRecommendations(
          providerId: metadata.providerId,
          isTv: metadata.isTv,
          limit: 18,
        );
        final sourceKey = RecommendationOwnershipMatcher.normalizeTitle(seed.media.title);
        final seen = <String>{};
        final cleaned = <CinematicTitleRecommendation>[];
        for (final item in fetched) {
          final titleKey = '${item.isTv}:${RecommendationOwnershipMatcher.normalizeTitle(item.title)}';
          if (item.providerId <= 0 || item.title.trim().isEmpty ||
              (item.isTv == seed.media.isSeries &&
               RecommendationOwnershipMatcher.normalizeTitle(item.title) == sourceKey) ||
              !seen.add(titleKey)) {
            continue;
          }
          cleaned.add(item);
        }
        if (mounted) setState(() => _recommendations[key] = List.unmodifiable(cleaned));
      } catch (_) {
        if (mounted) setState(() => _recommendations[key] = const <CinematicTitleRecommendation>[]);
      } finally {
        if (mounted) setState(() => _loading.remove(key));
      }
    }
  }

  Widget _shelf(String reason, MediaItem? seed) {
    if (seed == null) return const SizedBox.shrink();
    final key = _key(reason, seed);
    final items = _recommendations[key] ?? const <CinematicTitleRecommendation>[];
    if (items.isEmpty && !_loading.contains(key)) return const SizedBox.shrink();
    final title = reason == 'liked' ? 'Because you liked “${seed.title}”' : 'Because you watched “${seed.title}”';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscoverySectionHeader(
          title: title,
          subtitle: 'Catalog recommendations including titles you own, have watched, or have not added yet',
        ),
        if (items.isEmpty && _loading.contains(key))
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Finding related movies and shows…', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          )
        else
          HomeArrowRail(
            height: 260,
            itemCount: items.length,
            separatorExtent: 12,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) => _HomeTmdbRecommendationCard(
              recommendation: items[index],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _shelf('watched', widget.watchedSeed),
          _shelf('liked', widget.likedSeed),
        ],
      );
}

class HomeExternalPeopleRecommendationShelves extends StatefulWidget {
  const HomeExternalPeopleRecommendationShelves({super.key, required this.watched});
  final List<MediaItem> watched;

  @override
  State<HomeExternalPeopleRecommendationShelves> createState() =>
      _HomeExternalPeopleRecommendationShelvesState();
}

class _HomeExternalPeopleRecommendationShelvesState
    extends State<HomeExternalPeopleRecommendationShelves> {
  MediaItem? _source;
  List<({String person, List<CinematicTitleRecommendation> items})> _shelves =
      const <({String person, List<CinematicTitleRecommendation> items})>[];
  bool _loading = false;
  int _sequence = 0;

  MediaItem? _chooseSource(List<MediaItem> items) {
    for (final item in items.reversed) {
      if (_isMovieOrShowForRecommendation(item)) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomeExternalPeopleRecommendationShelves oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chooseSource(oldWidget.watched)?.id != _chooseSource(widget.watched)?.id) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final source = _chooseSource(widget.watched);
    final request = ++_sequence;
    if (source == null || !CinematicTitleMetadataService.isConfigured) {
      if (mounted) setState(() { _source = source; _shelves = const []; _loading = false; });
      return;
    }
    if (mounted) setState(() { _source = source; _shelves = const []; _loading = true; });
    try {
      final metadata = await CinematicTitleMetadataService.lookupTitle(
        title: source.title,
        isTv: source.isSeries,
        year: source.releaseYear ?? source.seriesStartYear,
      );
      if (!mounted || request != _sequence) return;
      if (metadata == null) return;
      final credits = metadata.castCredits
          .where((credit) => credit.personId != null && credit.name.trim().isNotEmpty)
          .take(4)
          .toList(growable: false);
      final output = <({String person, List<CinematicTitleRecommendation> items})>[];
      final sourceKey = RecommendationOwnershipMatcher.normalizeTitle(source.title);
      for (final credit in credits) {
        final items = await CinematicTitleMetadataService.lookupPersonCredits(
          personId: credit.personId!,
          limit: 30,
        );
        if (!mounted || request != _sequence) return;
        final seen = <String>{};
        final cleaned = items.where((item) {
          final key = '${item.isTv}:${RecommendationOwnershipMatcher.normalizeTitle(item.title)}';
          return RecommendationOwnershipMatcher.normalizeTitle(item.title) != sourceKey && seen.add(key);
        }).take(18).toList(growable: false);
        if (cleaned.isNotEmpty) output.add((person: credit.name, items: cleaned));
        if (output.length >= 4) break;
      }
      if (mounted && request == _sequence) setState(() => _shelves = List.unmodifiable(output));
    } catch (_) {
      // Local cast-based recommendations remain available if TMDB is unreachable.
    } finally {
      if (mounted && request == _sequence) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null || (_shelves.isEmpty && !_loading)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading && _shelves.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final shelf in _shelves) ...[
          _DiscoverySectionHeader(
            title: 'Because you saw ${shelf.person} in “${source.title}”',
            subtitle: 'More movies and shows featuring ${shelf.person}; badges show ownership and watch history',
          ),
          HomeArrowRail(
            height: 260,
            itemCount: shelf.items.length,
            separatorExtent: 12,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            itemBuilder: (context, index) => _HomeTmdbRecommendationCard(
              recommendation: shelf.items[index],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeTmdbRecommendationCard extends StatelessWidget {
  const _HomeTmdbRecommendationCard({
    required this.recommendation,
  });

  final CinematicTitleRecommendation recommendation;

  bool _wasWatched(AppController controller) {
    final target = RecommendationOwnershipMatcher.normalizeTitle(recommendation.title);
    return controller.watched.any((item) =>
        item.isAccessibleTo(controller.currentProfile) &&
        item.isSeries == recommendation.isTv &&
        <String>{
          RecommendationOwnershipMatcher.normalizeTitle(item.title),
          RecommendationOwnershipMatcher.normalizeTitle(item.originalTitle ?? ''),
          RecommendationOwnershipMatcher.normalizeTitle(item.canonicalTitle ?? ''),
        }.contains(target));
  }

  Future<void> _open(BuildContext context) async {
    final controller = AppController.instance;
    final localMatch = RecommendationOwnershipMatcher.findMediaForTitle(
      title: recommendation.title,
      isTv: recommendation.isTv,
      year: recommendation.releaseYear,
      controller: controller,
    );
    if (!context.mounted) return;
    if (localMatch != null) {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/details'),
        builder: (_) => MediaDetailsScreen(media: localMatch),
      ));
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/app/metadata-details'),
      builder: (_) => TmdbMetadataDetailsScreen(
        id: recommendation.providerId,
        type: recommendation.isTv ? 'tv' : 'movie',
        initialTitle: recommendation.title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final owned = RecommendationOwnershipMatcher.isRecommendationOwned(
      recommendation: recommendation,
      controller: controller,
    );
    final watched = _wasWatched(controller);
    final poster = recommendation.posterUrl;
    return SizedBox(
      width: 150,
      child: Material(
        color: _discoveryPanel,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_open(context)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(fit: StackFit.expand, children: [
                      if (poster != null)
                        CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 100),
                          placeholder: (_, __) => _mediaFallback(),
                          errorWidget: (_, __, ___) => _mediaFallback(),
                        )
                      else
                        _mediaFallback(),
                      Positioned(
                        left: 5,
                        top: 5,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          RecommendationOwnershipBadge(isOwned: owned, compact: true),
                          if (watched || owned) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xE817171D), borderRadius: BorderRadius.circular(999)),
                              child: Text(
                                watched ? 'WATCHED' : 'NOT WATCHED',
                                style: TextStyle(
                                  color: watched ? const Color(0xFF92D9FF) : const Color(0xFFFFD27A),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 7),
                Text(recommendation.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 4),
                Text('${recommendation.mediaTypeLabel}${recommendation.releaseYear == null ? '' : ' · ${recommendation.releaseYear}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaFallback() => const ColoredBox(
        color: Color(0xFF252433),
        child: Center(child: Icon(Icons.movie_outlined, size: 34, color: Colors.white24)),
      );
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
                            CachedNetworkImage(
                                imageUrl: track.artworkUrl!,
                                fit: BoxFit.cover,
                                fadeInDuration: const Duration(milliseconds: 100),
                                placeholder: (_, __) => const ColoredBox(
                                    color: Color(0xFF252532),
                                    child: Center(child: Icon(Icons.music_note_rounded))),
                                errorWidget: (_, __, ___) => const ColoredBox(
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

class _HomeFranchiseProgressDetailsScreen extends StatefulWidget {
  final HomeFranchiseProgressGroup group;

  const _HomeFranchiseProgressDetailsScreen({
    required this.group,
  });

  @override
  State<_HomeFranchiseProgressDetailsScreen> createState() =>
      _HomeFranchiseProgressDetailsScreenState();
}

class _HomeFranchiseProgressDetailsScreenState
    extends State<_HomeFranchiseProgressDetailsScreen> {
  late LibraryViewMode _selectedView;

  String get _viewScope => 'franchise-detail:${widget.group.id}';

  @override
  void initState() {
    super.initState();
    _selectedView = LibraryViewPreferenceStore.get(
      _viewScope,
      fallback: LibraryViewMode.list,
    );
  }

  void _selectView(LibraryViewMode mode) {
    LibraryViewPreferenceStore.set(_viewScope, mode);
    setState(() => _selectedView = mode);
  }

  void _openMedia(MediaItem media) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/details'),
        builder: (_) => MediaDetailsScreen(media: media),
      ),
    );
  }

  List<LibraryViewEntry> _ownedTitleEntries() => widget.group.ownedTitles
      .map(
        (media) => LibraryViewEntry(
          title: media.title,
          subtitle:
              '${_homeMediaTypeLabel(media.type)} • ${media.displayYearLabel ?? 'Year unknown'}',
          year: media.releaseYear,
          imageUrl: media.imageUrl,
          fallbackIcon: _homeMediaTypeLabel(media.type).toLowerCase().contains('show')
              ? Icons.tv_rounded
              : Icons.movie_outlined,
          onTap: () => _openMedia(media),
        ),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
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
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 12, 2, 2),
            child: Text(
              'Choose a view',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          LibraryViewModePicker(
            scope: _viewScope,
            value: _selectedView,
            onChanged: _selectView,
          ),
          if (group.ownedTitles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No titles from this group are currently indexed in your profile library. Reference examples below do not count as owned.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
              ),
            )
          else
            LibraryCollectionView(
              entries: _ownedTitleEntries(),
              mode: _selectedView,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              emptyMessage: 'No titles are available in this collection.',
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
          media: item,
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

class DiscoveryAllCollectionsScreen extends StatefulWidget {
  const DiscoveryAllCollectionsScreen({super.key});

  @override
  State<DiscoveryAllCollectionsScreen> createState() =>
      _DiscoveryAllCollectionsScreenState();
}

class _DiscoveryAllCollectionsScreenState
    extends State<DiscoveryAllCollectionsScreen> {
  LibraryViewMode _viewMode = LibraryViewPreferenceStore.get(
    'all-collections',
    fallback: LibraryViewMode.list,
  );

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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: LibraryViewModePicker(
                    scope: 'all-collections',
                    value: _viewMode,
                    onChanged: (mode) => setState(() => _viewMode = mode),
                    compact: true,
                  ),
                ),
                Expanded(
                  child: _viewMode == LibraryViewMode.list
                      ? ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: collections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            final items = _itemsFor(collection);
                            return _CollectionListTile(
                              collection: collection,
                              itemCount: items.length,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                settings: const RouteSettings(name: '/app/page/collection-details'),
                                builder: (_) => CollectionDetailsScreen(collection: collection),
                              )),
                              onShuffle: () => _startRandomFromCollection(context, collection),
                            );
                          },
                        )
                      : SingleChildScrollView(
                          child: LibraryCollectionView(
                            entries: collections.map((collection) {
                              final members = _itemsFor(collection);
                              final posterCandidates = members
                                  .where((item) => item.imageUrl?.trim().isNotEmpty == true)
                                  .toList(growable: false);
                              final customPoster = collection.customPosterUrl?.trim() ?? '';
                              final imageUrl = customPoster.isNotEmpty
                                  ? customPoster
                                  : (posterCandidates.isEmpty ? null : posterCandidates.first.imageUrl);
                              return LibraryViewEntry(
                                title: collection.name,
                                subtitle: '${members.length} title${members.length == 1 ? '' : 's'}${collection.description.trim().isEmpty ? '' : ' · ${collection.description.trim() }'}',
                                imageUrl: imageUrl,
                                fallbackIcon: Icons.collections_bookmark_outlined,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  settings: const RouteSettings(name: '/app/page/collection-details'),
                                  builder: (_) => CollectionDetailsScreen(collection: collection),
                                )),
                                trailing: IconButton(
                                  tooltip: 'Play a random item',
                                  onPressed: () => _startRandomFromCollection(context, collection),
                                  icon: const Icon(Icons.shuffle_rounded),
                                ),
                              );
                            }).toList(growable: false),
                            mode: _viewMode,
                          ),
                        ),
                ),
              ],
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
  final MediaItem? media;
  final VoidCallback onTap;
  final double width;
  final bool posterOnly;
  final bool? isOwned;
  final bool isWatched;

  const _DiscoveryMediaCard(
      {required this.title,
      required this.subtitle,
      required this.imageUrl,
      this.media,
      required this.onTap,
      this.width = 148,
      this.posterOnly = false,
      this.isOwned,
      this.isWatched = false});

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
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => _resolvedArtwork(),
                      errorWidget: (_, __, ___) => _resolvedArtwork(),
                    )
                  else
                    _resolvedArtwork(),
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
                  if (isWatched || isOwned == true)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xE817171D),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: (isWatched ? const Color(0xFF92D9FF) : const Color(0xFFFFD27A)).withValues(alpha: .8)),
                        ),
                        child: Text(
                          isWatched ? 'WATCHED' : 'NOT WATCHED',
                          style: TextStyle(
                            color: isWatched ? const Color(0xFF92D9FF) : const Color(0xFFFFD27A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .3,
                          ),
                        ),
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

  Widget _resolvedArtwork() {
    final media = this.media;
    if (media == null) return _mediaFallback();
    if (MediaArtworkAutoResolver.isAlbum(media)) {
      final artist = media.music.map((value) => value.trim()).firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => '',
          );
      return AlbumArtworkImage(
        title: media.title,
        artist: artist,
        imageUrl: media.imageUrl,
        fit: BoxFit.cover,
        placeholder: _mediaFallback(),
        errorPlaceholder: _mediaFallback(),
      );
    }
    if (MediaArtworkAutoResolver.isMovieOrShow(media)) {
      return CatalogPosterImage(
        media: media,
        fit: BoxFit.cover,
        placeholder: _mediaFallback(),
        errorPlaceholder: _mediaFallback(),
      );
    }
    return _mediaFallback();
  }

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
                CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 100),
                    placeholder: (_, __) => _fallback(),
                    errorWidget: (_, __, ___) => _fallback())
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
