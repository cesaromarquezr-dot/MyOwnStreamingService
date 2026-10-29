// FILE: `lib/details.dart`.
// Purpose: Implements the details portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'app_core.dart';
import 'music_catalog_screen.dart';
import 'cinematic_title.dart';
import 'artwork_gallery_screen.dart';
import 'artwork_selection_store.dart';
import 'reviews.dart';
import 'player.dart';
import 'group_watch.dart';
import 'localization.dart';
import 'shop.dart';
import 'media_actions.dart';
import 'media_continuity.dart';
import 'media_knowledge.dart';
import 'widgets/like_toggle_button.dart';
import 'widgets/added_by_profile_label.dart';
import 'social_sharing.dart';
import 'food_delivery.dart';
import 'catalog_entity_details.dart';
import 'page_customization_button.dart';
import 'recommendation_ownership.dart';
import 'media_artwork_auto_resolver.dart';
import 'energy_saver.dart';
import 'streaming_experience.dart';
import 'core/services/original_language_defaults.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// Implements the `MediaDetailsScreen` class for this feature or UI component.
class MediaDetailsScreen extends StatefulWidget {
  final MediaItem media;

  const MediaDetailsScreen({
    super.key,
    required this.media,
  });

  @override
  State<MediaDetailsScreen> createState() =>
      _MediaDetailsScreenState();
}

/// Implements the `_MediaDetailsScreenState` class for this feature or UI component.
class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  bool pressedPlay = false;
  bool pressedTrailer = false;
  String? _selectedEditionId;

  String selectedAudio = 'Default';
  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  int selectedSeasonIndex = 0;
  CinematicTitleMetadata? _providerTitleMetadata;
  /// Locally saved, profile-scoped artwork and trailer choices.
  String? _selectedPosterPath;
  String? _selectedBackdropPath;
  String? _selectedDetailsTrailerUrl;
  bool _randomizeAvailableTrailers = false;
  bool _loadingProviderMetadata = false;
  String? _providerMetadataError;
  final Map<int, List<Map<String, dynamic>>> _providerEpisodesBySeason =
      <int, List<Map<String, dynamic>>>{};
  final Set<int> _loadingProviderEpisodeSeasons = <int>{};
  final Set<int> _failedProviderEpisodeSeasons = <int>{};

  MediaItem get media => widget.media;

  bool _isLegacyTvType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show' ||
        type == 'show' ||
        type == 'series' ||
        type == 'television' ||
        type.contains('series');
  }

  bool get _supportsCinematicProviderMetadata {
    final type = media.type.toLowerCase();
    return !type.contains('album') &&
        !type.contains('song') &&
        !type.contains('track') &&
        !type.contains('music');
  }

  /// Details customization belongs to the currently selected profile.
  ///
  /// P1, P2 and P3 are profiles.
  /// They are NOT layout choices.
  DetailsCustomization get customization {
    return DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    );
  }

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    unawaited(_loadDefaultLanguageTracks());
    unawaited(EnergySaverController.instance.ensureLoaded(
      profileId: AppController.instance.currentProfile?.id,
    ).then((_) async {
      await Future<void>.delayed(Duration.zero);
      // Movie/show details already request TMDB title metadata below. The
      // generic resolver is needed here for album/music detail pages instead.
      if (mounted && !_supportsCinematicProviderMetadata) {
        await MediaArtworkAutoResolver.warmSelectedMedia(media);
      }
    }));
    if (CinematicTitleMetadataService.isConfigured &&
        _supportsCinematicProviderMetadata) {
      unawaited(_loadProviderTitleMetadata());
    }
  }

  Future<void> _loadProviderTitleMetadata() async {
    if (!CinematicTitleMetadataService.isConfigured ||
        !_supportsCinematicProviderMetadata ||
        _loadingProviderMetadata) {
      return;
    }
    if (mounted) {
      setState(() {
        _loadingProviderMetadata = true;
        _providerMetadataError = null;
        _providerEpisodesBySeason.clear();
        _failedProviderEpisodeSeasons.clear();
      });
    }
    try {
      final metadata = await CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: media.isSeries || _isLegacyTvType(media.type),
        year: media.releaseYear ?? media.seriesStartYear,
      );
      if (metadata != null &&
          EnergySaverController.instance.canRunBackgroundWork(pageId: 'details')) {
        unawaited(MediaArtworkAutoResolver.rememberResolvedArtwork(
          media,
          MediaArtworkResult(
            posterUrl: metadata.posterUrl,
            backdropPath: metadata.backdropPath,
            titleMetadata: metadata,
          ),
          profileId: AppController.instance.currentProfile?.id ?? 'guest',
          persistMissingPoster: media.imageUrl?.trim().isNotEmpty != true,
        ).catchError((Object _) {}));
      }
      final savedTrailerUrl = await _loadSavedDetailsTrailerUrl(metadata);
      final profileId = AppController.instance.currentProfile?.id ?? 'guest';
      final savedPosterPath = metadata == null
          ? null
          : await ArtworkSelectionStore.readPosterPath(
              profileId: profileId,
              mediaId: media.id,
            );
      final savedBackdropPath = metadata == null
          ? null
          : await ArtworkSelectionStore.readBackdropPath(
              profileId: profileId,
              mediaId: media.id,
            );
      if (!mounted) return;
      setState(() {
        _providerTitleMetadata = metadata;
        _selectedDetailsTrailerUrl = savedTrailerUrl;
        _selectedPosterPath = savedPosterPath;
        _selectedBackdropPath = savedBackdropPath;
        _providerMetadataError = metadata == null
            ? 'No exact TMDB title match found. Existing catalog credits have been kept unchanged.'
            : null;
      });
      if (metadata != null && metadata.isTv && metadata.seasons.isNotEmpty) {
        unawaited(_loadEpisodesForSelectedSeason());
      }
      if (metadata != null) {
        unawaited(AppController.instance.mergeProviderTitleCredits(
          mediaId: media.id,
          posterUrl: _selectedPosterPath == null
              ? metadata.posterUrl
              : CinematicTitleMetadataService.imageUrl(_selectedPosterPath),
          actors: metadata.cast,
          characters: metadata.characters,
          directors: metadata.directors,
          writers: metadata.writers,
          music: metadata.music,
          providerGenres: metadata.genres,
          providerKeywords: metadata.keywords,
          providerReleaseDate: metadata.releaseDate,
          providerLastAirDate: metadata.lastAirDate,
          providerStatus: metadata.status,
        ));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _providerMetadataError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loadingProviderMetadata = false);
    }
  }

  Future<void> _loadDefaultLanguageTracks() async {
    final preferences = await StreamingExperiencePreferences.load(
      profileId: AppController.instance.currentProfile?.id,
    );
    final targetLanguage = OriginalLanguageDefaults.resolveForMedia(media);
    final audio = OriginalLanguageDefaults.bestTrack(
          media.audioTracks,
          targetLanguage: preferences.preferOriginalLanguageTracks
              ? targetLanguage
              : null,
        ) ??
        'Default';
    final subtitle = preferences.subtitlesEnabled
        ? OriginalLanguageDefaults.bestTrack(
            media.subtitles,
            targetLanguage: preferences.preferOriginalLanguageTracks
                ? targetLanguage
                : null,
            subtitles: true,
          )
        : null;
    if (!mounted) return;
    setState(() {
      selectedAudio = audio;
      selectedSubtitle = subtitle;
      subtitlesEnabled = preferences.subtitlesEnabled && subtitle != null;
    });
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    // Album records can be opened from many shared discovery/search/library
    // cards. Normalize their destination here so none accidentally land in
    // the movie/TV Details layout.
    if (isMusicAlbumType(media.type)) {
      return MusicAlbumPageScreen(media: media);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_detailsBackdropUrl != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Image.network(
                  _detailsBackdropUrl!,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: .76),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0xE6090909)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFF090909),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              // The global navigation already supplies Home. The details body
              // renders the media title, so no duplicate title/back row here.
              actions: [
                if (_supportsCinematicProviderMetadata)
                  IconButton(
                    tooltip: 'Choose poster and backdrop',
                    icon: const Icon(Icons.photo_library_outlined),
                    onPressed: _openArtworkGalleryForCurrentMedia,
                  ),
                const PageCustomizeButton(pageId: 'details'),
                IconButton(
                  tooltip: 'Food & Delivery',
                  icon: const Icon(Icons.delivery_dining_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FoodOrderingScreen(viewingContext: media.title))),
                ),
                IconButton(
                  tooltip: 'Share to chats',
                  onPressed: () => showSocialShareDialog(
                    context,
                    title: media.title,
                    message: 'Recommendation: ${media.title}',
                    mediaReference: {
                      'type': 'recommendation',
                      'title': media.title,
                      'mediaId': media.id,
                      'mediaType': media.type,
                    },
                  ),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: _buildDetailsPage(),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? get _detailsBackdropUrl =>
      CinematicTitleMetadataService.imageUrl(_selectedBackdropPath, size: 'w1280') ??
      _providerTitleMetadata?.backdropUrl;

  /// Performs `_buildDetailsPage` for this feature. Update this documentation when its contract changes.
  Widget _buildDetailsPage() {
    if (AppController.instance.currentProfile == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: UniversalText('No profile selected.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEditionSelector(),
          // The Shop marketplace action now lives in the unified purchase
          // card below, preventing duplicate Shop buttons in Details.
          for (final section in customization.sectionOrder)
            if (section != 'Shop') _buildSection(section),
          if (!_isCurrentMediaOwned) _buildExternalPurchaseOptions(),
          MediaContinuityPanel(mediaId: media.id, mediaTitle: media.title),
          MediaFranchiseConnectionsPanel(mediaId: media.id, hasSeasons: isTvShow),
          const SizedBox(height: 12),
          MediaKnowledgePanel(mediaWorkId: media.id, mediaTitle: media.title),
        ],
      ),
    );
  }

  /// Returns editions explicitly linked to the same canonical work.
  /// Similar titles are never merged by title text alone.
  List<MediaItem> _linkedEditions() {
    if (media.isSeries) return <MediaItem>[];
    final workId = media.canonicalWorkId?.trim();
    if (workId == null || workId.isEmpty) return <MediaItem>[media];

    final byId = <String, MediaItem>{media.id: media};
    for (final candidate in AppController.instance.library) {
      if (candidate.id == media.id || candidate.isSeries) continue;
      if (candidate.canonicalWorkId?.trim() == workId) {
        byId.putIfAbsent(candidate.id, () => candidate);
      }
    }
    final editions = byId.values.toList()
      ..sort((a, b) => (a.editionReleaseYear ?? a.releaseYear ?? 0)
          .compareTo(b.editionReleaseYear ?? b.releaseYear ?? 0));
    return editions;
  }

  MediaItem? get _selectedEdition {
    final editions = _linkedEditions();
    if (editions.length == 1) return editions.first;
    final id = _selectedEditionId;
    if (id == null) return null;
    for (final edition in editions) {
      if (edition.id == id) return edition;
    }
    return null;
  }

  /// Multiple editions require an explicit selection; a single edition
  /// automatically becomes the playback target so Play remains enabled.
  Widget _buildEditionSelector() {
    final editions = _linkedEditions();
    if (editions.length < 2) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFF151515),
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UniversalText('Versions & Cuts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const UniversalText(
              'Select the exact version you want to watch before pressing Play.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedEditionId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Choose a version',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select a version'),
              items: editions.map((edition) {
                final label = edition.displayEditionLabel ?? 'Standard / Original Version';
                final year = edition.editionReleaseYear ?? edition.releaseYear;
                return DropdownMenuItem<String>(
                  value: edition.id,
                  child: Text(year == null ? label : '$label ($year)', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedEditionId = value),
            ),
            if (_selectedEdition == null) ...[
              const SizedBox(height: 8),
              const UniversalText(
                'Play is disabled until you choose a version.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows the extended data returned by TMDB. This is intentionally outside
  /// the user-customizable section list so the freshly fetched provider data is
  /// visible even when a saved Details layout predates this feature.
  String _formatProviderMoney(int? value) {
    if (value == null || value <= 0) return 'Not provided';
    return 'US\$${_formatProviderInteger(value)}';
  }

  String _formatProviderInteger(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  String _providerLanguageName(String code) {
    const names = <String, String>{
      'ar': 'Arabic', 'de': 'German', 'en': 'English', 'es': 'Spanish',
      'fr': 'French', 'hi': 'Hindi', 'it': 'Italian', 'ja': 'Japanese',
      'ko': 'Korean', 'pt': 'Portuguese', 'ru': 'Russian', 'th': 'Thai',
      'tr': 'Turkish', 'zh': 'Chinese', 'nl': 'Dutch', 'sv': 'Swedish',
      'da': 'Danish', 'pl': 'Polish', 'no': 'Norwegian', 'fi': 'Finnish',
    };
    final name = names[code.toLowerCase()];
    return name == null ? code.toUpperCase() : '$name ($code)';
  }

  Future<void> _openArtworkGallery(CinematicTitleMetadata metadata) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ArtworkGalleryScreen(
          media: media,
          metadata: metadata,
          initialPosterPath: _selectedPosterPath,
          initialBackdropPath: _selectedBackdropPath,
          onPosterSet: (path) {
            if (mounted) setState(() => _selectedPosterPath = path);
          },
          onBackdropSet: (path) {
            if (mounted) setState(() => _selectedBackdropPath = path);
          },
        ),
      ),
    );
  }

  Future<void> _openArtworkGalleryForCurrentMedia() async {
    if (!_supportsCinematicProviderMetadata) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Poster and backdrop galleries are available for movies and series.'),
      ));
      return;
    }
    if (!CinematicTitleMetadataService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connect and start the metadata backend to load poster and backdrop choices.'),
      ));
      return;
    }

    var metadata = _providerTitleMetadata;
    if (metadata == null) {
      try {
        metadata = await CinematicTitleMetadataService.lookupTitle(
          title: media.title,
          isTv: media.isSeries,
          year: media.releaseYear ?? media.seriesStartYear,
        );
      } catch (_) {
        metadata = null;
      }
      if (!mounted) return;
      if (metadata != null) {
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
        setState(() {
          _providerTitleMetadata = metadata;
          _selectedPosterPath = savedPoster;
          _selectedBackdropPath = savedBackdrop;
        });
      }
    }

    if (!mounted) return;
    if (metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No exact artwork gallery was found for "${media.title}". Verify the title and try again.'),
      ));
      return;
    }
    if (metadata.posterPaths.isEmpty && metadata.backdropPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No poster or backdrop choices are available for "${media.title}".'),
      ));
      return;
    }
    await _openArtworkGallery(metadata);
  }

  Widget _buildProviderVideos(List<CinematicTitleVideo> videos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Videos (${videos.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Choose one default YouTube trailer, or randomize playback across all available YouTube videos.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35),
        ),
        if (_playableProviderVideos.isNotEmpty)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _randomizeAvailableTrailers,
            onChanged: _setRandomTrailerMode,
            title: const Text('Randomize from all available videos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            subtitle: Text('${_playableProviderVideos.length} YouTube video(s) in the random pool', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        if ((_selectedDetailsTrailerUrl?.trim().isNotEmpty ?? false) &&
            (media.trailerUrl?.trim().isNotEmpty ?? false))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _useCatalogTrailer,
              icon: const Icon(Icons.settings_backup_restore, size: 16),
              label: const Text('Use saved catalog trailer'),
            ),
          ),
        if (videos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text('No public videos currently listed by TMDB.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        else
          ...videos.map((video) {
            final isYouTube = video.site.trim().toLowerCase() == 'youtube';
            final isSelected = _isDetailsPageTrailer(video);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                isSelected ? Icons.play_circle_filled : Icons.play_circle_outline,
                color: isSelected ? Colors.greenAccent : Colors.white70,
              ),
              title: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${video.site} · ${video.type}${video.official ? ' · Official' : ''}${isSelected ? ' · Details-page trailer' : ''}',
                style: TextStyle(
                  color: isSelected ? Colors.greenAccent : Colors.white54,
                  fontSize: 11,
                ),
              ),
              trailing: IconButton(
                tooltip: isSelected
                    ? 'Selected as the Details-page trailer'
                    : (isYouTube
                        ? 'Set as the Details-page trailer'
                        : 'In-app trailer playback currently supports YouTube videos'),
                icon: Icon(
                  isSelected ? Icons.check_circle : Icons.movie_filter_outlined,
                  color: isSelected ? Colors.greenAccent : (isYouTube ? Colors.white70 : Colors.white24),
                  size: 21,
                ),
                onPressed: !isYouTube || video.url == null || isSelected
                    ? null
                    : () => _setAsDetailsPageTrailer(video),
              ),
              onTap: video.url == null ? null : () => _openProviderUrl(video.url!),
            );
          }),
      ],
    );
  }

  String _detailsTrailerPreferenceKey() {
    String token(String raw, String fallback) {
      final cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      return cleaned.isEmpty ? fallback : cleaned;
    }

    final profileId = AppController.instance.currentProfile?.id ?? '';
    return 'moss_details_page_trailer_${token(profileId, 'guest')}_${token(media.id, media.title)}';
  }

  String _detailsTrailerRandomPreferenceKey() =>
      '${_detailsTrailerPreferenceKey()}_random';

  List<CinematicTitleVideo> get _playableProviderVideos =>
      (_providerTitleMetadata?.videos ?? const <CinematicTitleVideo>[])
          .where((video) =>
              video.site.trim().toLowerCase() == 'youtube' &&
              video.url?.trim().isNotEmpty == true)
          .toList(growable: false);

  Future<void> _setRandomTrailerMode(bool enabled) async {
    final candidates = _playableProviderVideos;
    if (enabled && candidates.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_detailsTrailerRandomPreferenceKey(), enabled);
      if (!mounted) return;
      setState(() => _randomizeAvailableTrailers = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled
            ? 'Trailer playback will randomly select from ${candidates.length} available YouTube videos.'
            : 'Trailer playback will use the selected default trailer.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save trailer playback preference.')),
      );
    }
  }

  Future<String?> _loadSavedDetailsTrailerUrl(
    CinematicTitleMetadata? metadata,
  ) async {
    if (metadata == null) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _detailsTrailerPreferenceKey();
      _randomizeAvailableTrailers =
          preferences.getBool(_detailsTrailerRandomPreferenceKey()) ?? false;
      final savedUrl = preferences.getString(key)?.trim() ?? '';
      if (savedUrl.isEmpty) return null;
      final stillAvailable = metadata.videos.any((video) =>
          video.site.trim().toLowerCase() == 'youtube' && video.url == savedUrl);
      if (stillAvailable) return savedUrl;
      await preferences.remove(key);
    } catch (_) {
      // A local preference failure should not block title metadata from loading.
    }
    return null;
  }

  bool _isDetailsPageTrailer(CinematicTitleVideo video) {
    final savedUrl = _selectedDetailsTrailerUrl?.trim() ?? '';
    final effectiveUrl = savedUrl.isNotEmpty
        ? savedUrl
        : (media.trailerUrl?.trim() ?? '');
    return effectiveUrl.isNotEmpty && video.url == effectiveUrl;
  }

  Future<void> _useCatalogTrailer() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_detailsTrailerPreferenceKey());
      await preferences.setBool(_detailsTrailerRandomPreferenceKey(), false);
      if (!mounted) return;
      setState(() {
        _selectedDetailsTrailerUrl = null;
        _randomizeAvailableTrailers = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Using the saved catalog trailer again.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reset the trailer selection. Please try again.')),
      );
    }
  }

  Future<void> _setAsDetailsPageTrailer(CinematicTitleVideo video) async {
    final url = video.url;
    if (url == null || video.site.trim().toLowerCase() != 'youtube') return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_detailsTrailerPreferenceKey(), url);
      await preferences.setBool(_detailsTrailerRandomPreferenceKey(), false);
      if (!mounted) return;
      setState(() {
        _selectedDetailsTrailerUrl = url;
        _randomizeAvailableTrailers = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('“${video.name}” is now the trailer for ${media.title} on this Details page.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the selected trailer. Please try again.')),
      );
    }
  }

  Future<void> _openProviderUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that TMDB link.')),
      );
    }
  }

  /// Opens retailer search results rather than claiming that a specific copy
  /// is in stock. Availability, format and regional eligibility are determined
  /// by the retailer after the user follows the link.
  Widget _buildExternalPurchaseOptions() {
    final query = '${media.title} ${media.displayEditionLabel ?? ''} ${media.editionReleaseYear ?? media.releaseYear ?? ''}'.trim();
    final encoded = Uri.encodeQueryComponent(query);
    final retailers = <({String name, IconData icon, String url})>[
      (name: 'Amazon', icon: Icons.shopping_bag_outlined, url: 'https://www.amazon.com/s?k=$encoded'),
      (name: 'Walmart', icon: Icons.storefront_outlined, url: 'https://www.walmart.com/search?q=$encoded'),
      (name: 'Mercado Libre', icon: Icons.store_mall_directory_outlined, url: 'https://listado.mercadolibre.com.mx/${Uri.encodeComponent(query)}'),
      (name: 'eBay', icon: Icons.sell_outlined, url: 'https://www.ebay.com/sch/i.html?_nkw=$encoded'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Card(
        color: const Color(0xFF151515),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const UniversalText('Find to buy or rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const UniversalText('Search retailers for digital rentals, purchases, DVDs, Blu-rays, or used copies. These are search links; stock, format, price, and region availability are confirmed by each retailer.', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (customization.showShop)
                ContextualShopButton.forMedia(context, media),
              for (final retailer in retailers)
                OutlinedButton.icon(
                  icon: Icon(retailer.icon, size: 18),
                  label: Text(retailer.name),
                  onPressed: () async {
                    final uri = Uri.tryParse(retailer.url);
                    if (uri == null) return;
                    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!opened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${retailer.name}.')));
                    }
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION ROUTER
  // ===========================================================================

  /// Performs `_buildSection` for this feature. Update this documentation when its contract changes.
  Widget _buildSection(String section) {
    switch (section) {
      case 'Poster':
        if (!customization.showPoster) {
          return const SizedBox.shrink();
        }
        return _buildPoster();

      case 'Title':
        if (!customization.showTitle) {
          return const SizedBox.shrink();
        }
        return _buildTitle();

      case 'Metadata':
        if (!customization.showMetadata) {
          return const SizedBox.shrink();
        }
        return _buildMetadata();

      case 'Ownership':
        if (!customization.showOwnership) {
          return const SizedBox.shrink();
        }
        return _buildOwnership();

      case 'Description':
        if (!customization.showDescription) {
          return const SizedBox.shrink();
        }
        return _buildDescription();

      case 'Seasons':
        if (!isTvShow || !customization.showSeasons) {
          return const SizedBox.shrink();
        }
        return _buildSeasonsSection();

      case 'Play':
        if (!customization.showPlay) {
          return const SizedBox.shrink();
        }
        return _buildPlay();

      case 'Trailer':
        if (!customization.showTrailer) {
          return const SizedBox.shrink();
        }
        return _buildTrailer();

      case 'Shop':
        if (!customization.showShop) {
          return const SizedBox.shrink();
        }
        return _buildShop();

      case 'Reviews':
        return _buildReviews();

      case 'Recommendations':
        // Recommendation, 'because you watched', and mood discovery now live on Home.
        return const SizedBox.shrink();

      case 'Audio & Subtitles':
        if (!customization.showAudioSubtitles) {
          return const SizedBox.shrink();
        }
        return _buildAudioSubtitles();

      case 'Reactions':
        if (!customization.showReactions) {
          return const SizedBox.shrink();
        }
        return _buildReactions();

      case 'Cast & Crew':
        return _buildCastCrew();

      case 'Information':
        if (!customization.showInformation) {
          return const SizedBox.shrink();
        }
        return _buildInformation();

      case 'Library':
        if (!customization.showLibrary) {
          return const SizedBox.shrink();
        }
        return _buildLibrary();

      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // TV SHOW DETECTION
  // ===========================================================================

  bool get isTvShow => media.isSeries;

  int? get _displaySeasonCount =>
      seasons.isNotEmpty ? seasons.length : media.displaySeasonCount;

  // ===========================================================================
  // SEASONS / EPISODES
  // ===========================================================================

  List<Map<String, dynamic>> get seasons {
    final localSeasons = media.seasons
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final providerSeasons = _providerTitleMetadata?.isTv == true
        ? _providerTitleMetadata!.seasons
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    if (providerSeasons.isEmpty) return localSeasons;

    final mergedByNumber = <int, Map<String, dynamic>>{};
    final seasonsWithoutNumber = <Map<String, dynamic>>[];
    for (final providerSeason in providerSeasons) {
      final number = _integerValue(
        providerSeason['seasonNumber'] ??
            providerSeason['season_number'] ??
            providerSeason['number'],
      );
      if (number == null) {
        seasonsWithoutNumber.add(providerSeason);
      } else {
        mergedByNumber[number] = providerSeason;
      }
    }
    for (final localSeason in localSeasons) {
      final number = _integerValue(
        localSeason['seasonNumber'] ??
            localSeason['season_number'] ??
            localSeason['season'] ??
            localSeason['number'],
      );
      if (number == null) {
        seasonsWithoutNumber.add(localSeason);
        continue;
      }
      final providerSeason = mergedByNumber[number];
      if (providerSeason == null) {
        mergedByNumber[number] = localSeason;
        continue;
      }
      final merged = Map<String, dynamic>.from(providerSeason);
      for (final entry in localSeason.entries) {
        final value = entry.value;
        if (value != null && (value is! String || value.trim().isNotEmpty)) {
          merged[entry.key] = value;
        }
      }
      final localEpisodes = localSeason['episodes'];
      if (localEpisodes is List && localEpisodes.isNotEmpty) {
        merged['episodes'] = localEpisodes;
      }
      mergedByNumber[number] = merged;
    }
    final result = <Map<String, dynamic>>[
      ...mergedByNumber.values,
      ...seasonsWithoutNumber,
    ];
    result.sort((a, b) => (_integerValue(
              a['seasonNumber'] ?? a['season_number'] ?? a['season'] ?? a['number'],
            ) ?? 0)
        .compareTo(_integerValue(
              b['seasonNumber'] ?? b['season_number'] ?? b['season'] ?? b['number'],
            ) ?? 0));
    return result;
  }

  int? _seasonNumberFrom(Map<String, dynamic> season) => _integerValue(
        season['seasonNumber'] ??
            season['season_number'] ??
            season['season'] ??
            season['number'],
      );

  int? _episodeNumberFrom(Map<String, dynamic> episode) {
    final explicit = _integerValue(
      episode['episodeNumber'] ??
          episode['episode_number'] ??
          episode['episode'] ??
          episode['number'],
    );
    if (explicit != null) return explicit;
    final label = (episode['episodeCode'] ??
            episode['filename'] ??
            episode['title'] ??
            episode['name'] ??
            '')
        .toString();
    final patterns = <RegExp>[
      RegExp(r'\bS\d{1,2}\s*E(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\bEpisode\s*#?0*(\d{1,3})\b', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(label);
      if (match != null) return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  Future<void> _loadEpisodesForSelectedSeason() async {
    final ordered = _orderedSeasons();
    if (ordered.isEmpty) return;
    final index = selectedSeasonIndex >= 0 && selectedSeasonIndex < ordered.length
        ? selectedSeasonIndex
        : 0;
    await _loadProviderSeasonEpisodes(ordered[index]);
  }

  Future<void> _loadProviderSeasonEpisodes(
    Map<String, dynamic> season,
  ) async {
    final metadata = _providerTitleMetadata;
    final seasonNumber = _seasonNumberFrom(season);
    if (metadata == null ||
        !metadata.isTv ||
        seasonNumber == null ||
        !CinematicTitleMetadataService.isConfigured ||
        _providerEpisodesBySeason.containsKey(seasonNumber) ||
        _loadingProviderEpisodeSeasons.contains(seasonNumber) ||
        _failedProviderEpisodeSeasons.contains(seasonNumber)) {
      return;
    }
    if (!mounted) return;
    setState(() => _loadingProviderEpisodeSeasons.add(seasonNumber));
    try {
      final episodes = await CinematicTitleMetadataService.lookupTvSeasonEpisodes(
        providerId: metadata.providerId,
        seasonNumber: seasonNumber,
      );
      if (!mounted) return;
      setState(() {
        _providerEpisodesBySeason[seasonNumber] = episodes;
        _failedProviderEpisodeSeasons.remove(seasonNumber);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedProviderEpisodeSeasons.add(seasonNumber));
    } finally {
      if (mounted) {
        setState(() => _loadingProviderEpisodeSeasons.remove(seasonNumber));
      }
    }
  }

  List<Map<String, dynamic>> _orderedSeasons() {
    final result = List<Map<String, dynamic>>.from(seasons);

    int? numberFor(Map<String, dynamic> season) {
      final explicit = _integerValue(
        season['seasonNumber'] ??
            season['season_number'] ??
            season['season'] ??
            season['number'],
      );
      if (explicit != null) return explicit;

      final label = _seasonTitle(season);
      final match = RegExp(
        r'\b(?:season|series|s)\s*#?0*(\d+)\b',
        caseSensitive: false,
      ).firstMatch(label);
      return match == null ? null : int.tryParse(match.group(1) ?? '');
    }

    result.sort((a, b) {
      final aNumber = numberFor(a);
      final bNumber = numberFor(b);
      if (aNumber != null && bNumber != null) {
        final numberCompare = aNumber.compareTo(bNumber);
        if (numberCompare != 0) return numberCompare;
      } else if (aNumber != null) {
        return -1;
      } else if (bNumber != null) {
        return 1;
      }

      final aTitle = _seasonTitle(a).toLowerCase();
      final bTitle = _seasonTitle(b).toLowerCase();
      return aTitle.compareTo(bTitle);
    });

    if (customization.seasonOrder == 'Bottom to Top') {
      return result.reversed.toList(growable: false);
    }
    return result;
  }

  List<Map<String, dynamic>> _episodesForSeason(
    Map<String, dynamic> season,
  ) {
    final raw = season['episodes'];
    final localEpisodes = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) localEpisodes.add(Map<String, dynamic>.from(item));
      }
    }
    final seasonNumber = _seasonNumberFrom(season);
    final providerEpisodes = seasonNumber == null
        ? <Map<String, dynamic>>[]
        : (_providerEpisodesBySeason[seasonNumber] ?? <Map<String, dynamic>>[]);
    if (providerEpisodes.isEmpty) return _sortEpisodes(localEpisodes);
    if (localEpisodes.isEmpty) return _sortEpisodes(providerEpisodes);

    final usedLocalIndexes = <int>{};
    final merged = <Map<String, dynamic>>[];
    for (final providerEpisode in providerEpisodes) {
      final providerNumber = _episodeNumberFrom(providerEpisode);
      var localIndex = -1;
      for (var i = 0; i < localEpisodes.length; i++) {
        if (usedLocalIndexes.contains(i)) continue;
        final localNumber = _episodeNumberFrom(localEpisodes[i]);
        if (providerNumber != null && localNumber == providerNumber) {
          localIndex = i;
          break;
        }
      }
      if (localIndex < 0) {
        final providerOnly = Map<String, dynamic>.from(providerEpisode);
        providerOnly['metadataOnly'] = true;
        merged.add(providerOnly);
        continue;
      }
      usedLocalIndexes.add(localIndex);
      final localEpisode = localEpisodes[localIndex];
      final combined = Map<String, dynamic>.from(providerEpisode);
      // Keep locally indexed identity/playback fields while enriching the
      // visible name, overview, runtime, air date, rating and still from TMDB.
      for (final key in <String>[
        'id', 'playbackUrl', 'streamingUrl', 'streamUrl', 'url', 'path',
        'filePath', 'mediaId', 'type', 'trailerUrl', 'audioTracks', 'subtitles',
      ]) {
        final value = localEpisode[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          combined[key] = value;
        }
      }
      combined['metadataOnly'] = false;
      if ((combined['imageUrl'] == null || combined['imageUrl'].toString().isEmpty) &&
          localEpisode['imageUrl'] != null) {
        combined['imageUrl'] = localEpisode['imageUrl'];
      }
      merged.add(combined);
    }
    for (var i = 0; i < localEpisodes.length; i++) {
      if (!usedLocalIndexes.contains(i)) merged.add(localEpisodes[i]);
    }
    return _sortEpisodes(merged);
  }

  List<Map<String, dynamic>> _sortEpisodes(List<Map<String, dynamic>> source) {
    final result = List<Map<String, dynamic>>.from(source);

    int? episodeNumberFor(Map<String, dynamic> episode) {
      final explicit = _integerValue(
        episode['episodeNumber'] ??
            episode['episode_number'] ??
            episode['episode'] ??
            episode['number'],
      );
      if (explicit != null) return explicit;

      final label = (episode['episodeCode'] ??
              episode['filename'] ??
              episode['title'] ??
              episode['name'] ??
              '')
          .toString();
      final patterns = <RegExp>[
        RegExp(r'\bS\d{1,2}\s*E(\d{1,3})\b', caseSensitive: false),
        RegExp(r'\bEpisode\s*#?0*(\d{1,3})\b', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(label);
        if (match != null) return int.tryParse(match.group(1) ?? '');
      }
      return null;
    }

    int? episodeEndFor(Map<String, dynamic> episode) => _integerValue(
          episode['episodeEndNumber'] ??
              episode['episode_end_number'] ??
              episode['endEpisodeNumber'],
        );

    result.sort((a, b) {
      final aNumber = episodeNumberFor(a);
      final bNumber = episodeNumberFor(b);
      if (aNumber != null && bNumber != null) {
        final numberCompare = aNumber.compareTo(bNumber);
        if (numberCompare != 0) return numberCompare;
        final endCompare = (episodeEndFor(a) ?? aNumber)
            .compareTo(episodeEndFor(b) ?? bNumber);
        if (endCompare != 0) return endCompare;
      } else if (aNumber != null) {
        return -1;
      } else if (bNumber != null) {
        return 1;
      }

      final aTitle = (a['title'] ?? a['name'] ?? '').toString().toLowerCase();
      final bTitle = (b['title'] ?? b['name'] ?? '').toString().toLowerCase();
      return aTitle.compareTo(bTitle);
    });

    return result;
  }

  /// Performs `_buildSeasonsSection` for this feature. Update this documentation when its contract changes.
  Widget _buildSeasonsSection() {
    final orderedSeasons = _orderedSeasons();

    if (orderedSeasons.isEmpty) {
      if (!isTvShow) return const SizedBox.shrink();
      final loading = _loadingProviderMetadata;
      final message = loading
          ? 'Loading seasons and episode guide…'
          : (_providerMetadataError != null
              ? 'Season and episode details could not be loaded. Check your metadata backend and try refreshing TMDB details.'
              : 'Season and episode information will appear here when it is available from TMDB or your media server.');
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 30),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Seasons & Episodes', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [
                if (loading) ...[
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4))),
              ]),
            ],
          ),
        ),
      );
    }

    if (selectedSeasonIndex >= orderedSeasons.length) {
      selectedSeasonIndex = 0;
    }

    final selectedSeason = orderedSeasons[selectedSeasonIndex];

    final episodes = _episodesForSeason(selectedSeason);
    final selectedSeasonNumber = _seasonNumberFrom(selectedSeason);
    final loadingEpisodes = selectedSeasonNumber != null &&
        _loadingProviderEpisodeSeasons.contains(selectedSeasonNumber);
    final seasonOverview = (selectedSeason['overview'] ?? selectedSeason['description'])
        ?.toString()
        .trim();

    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 30,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          18,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UniversalText('Seasons',
              textAlign: _textAlignment(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _buildSeasonSelector(
              orderedSeasons,
            ),
            const SizedBox(height: 20),
            Text(
              _seasonTitle(selectedSeason),
              textAlign: _textAlignment(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (seasonOverview != null && seasonOverview.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                seasonOverview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            if (episodes.isEmpty && loadingEpisodes)
              _buildLoadingEpisodes()
            else if (episodes.isEmpty)
              _buildNoEpisodes()
            else
              _buildEpisodes(episodes),
          ],
        ),
      ),
    );
  }

  /// Performs `_buildSeasonSelector` for this feature. Update this documentation when its contract changes.
  Widget _buildSeasonSelector(
    List<Map<String, dynamic>> orderedSeasons,
  ) {
    if (customization.seasonSelectorStyle == 'Dropdown') {
      return Align(
        alignment: _seasonAlignment(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DropdownButtonFormField<int>(
            initialValue: selectedSeasonIndex,
            decoration: InputDecoration(
              labelText: tr('Season'),
            ),
            items: List.generate(
              orderedSeasons.length,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Text(
                  _seasonTitle(orderedSeasons[index]),
                ),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedSeasonIndex = value;
                });
                unawaited(_loadProviderSeasonEpisodes(orderedSeasons[value]));
              }
            },
          ),
        ),
      );
    }

    return Align(
      alignment: _seasonAlignment(),
      child: Wrap(
        alignment: _seasonWrapAlignment(),
        spacing: 9,
        runSpacing: 9,
        children: List.generate(
          orderedSeasons.length,
          (index) {
            final season = orderedSeasons[index];
            final selected = index == selectedSeasonIndex;

            return _SeasonButton(
              label: _seasonTitle(season),
              selected: selected,
              onTap: () {
                setState(() {
                  selectedSeasonIndex = index;
                });
                unawaited(_loadProviderSeasonEpisodes(season));
              },
            );
          },
        ),
      ),
    );
  }

  /// Performs `_buildEpisodes` for this feature. Update this documentation when its contract changes.
  Widget _buildEpisodes(
    List<Map<String, dynamic>> episodes,
  ) {
    final orderedEpisodes = List<Map<String, dynamic>>.from(
      episodes,
    );

    return Column(
      children: List.generate(
        orderedEpisodes.length,
        (index) {
          final episode = orderedEpisodes[index];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == orderedEpisodes.length - 1
                  ? 0
                  : 10,
            ),
            child: _EpisodeCard(
              episode: episode,
              onPlay: () {
                _playEpisode(episode);
              },
            ),
          );
        },
      ),
    );
  }

  /// Performs `_buildNoEpisodes` for this feature. Update this documentation when its contract changes.
  Widget _buildLoadingEpisodes() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Loading episode titles, descriptions and runtimes…', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  /// Performs `_buildNoEpisodes` for this feature. Update this documentation when its contract changes.
  Widget _buildNoEpisodes() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const UniversalText("No episode details are available for this season yet. The server's local episode list will still be shown whenever it is indexed.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Performs `_seasonTitle` for this feature. Update this documentation when its contract changes.
  String _seasonTitle(
    Map<String, dynamic> season,
  ) {
    final name = season['name'] ??
        season['title'] ??
        season['seasonName'];

    if (name != null &&
        name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    final number = _integerValue(
          season['number'],
        ) ??
        _integerValue(
          season['seasonNumber'],
        );

    if (number != null) {
      return 'Season $number';
    }

    return 'Season';
  }

  int? _integerValue(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  /// Performs `_seasonAlignment` for this feature. Update this documentation when its contract changes.
  Alignment _seasonAlignment() {
    switch (customization.seasonPlacement) {
      case 'Left':
        return Alignment.centerLeft;

      case 'Right':
        return Alignment.centerRight;

      case 'Center':
      default:
        return Alignment.center;
    }
  }

  /// Performs `_seasonWrapAlignment` for this feature. Update this documentation when its contract changes.
  WrapAlignment _seasonWrapAlignment() {
    switch (customization.seasonPlacement) {
      case 'Left':
        return WrapAlignment.start;

      case 'Right':
        return WrapAlignment.end;

      case 'Center':
      default:
        return WrapAlignment.center;
    }
  }

  /// Performs `_playEpisode` for this feature. Update this documentation when its contract changes.
  void _playEpisode(
    Map<String, dynamic> episode,
  ) {
    if (episode['metadataOnly'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This episode has metadata but is not linked to a playable item in your library or Jellyfin server yet.'),
        ),
      );
      return;
    }
    final episodeMedia = _mediaFromEpisode(episode);

    if (episodeMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText('This episode does not contain enough information to play.',
          ),
        ),
      );
      return;
    }

    final orderedSeasons = _orderedSeasons();
    final selectedSeason = selectedSeasonIndex >= 0 && selectedSeasonIndex < orderedSeasons.length
        ? orderedSeasons[selectedSeasonIndex]
        : const <String, dynamic>{};
    final seasonNumber = selectedSeason['seasonNumber'] ??
        selectedSeason['season_number'] ??
        selectedSeason['number'] ??
        selectedSeason['season'];
    final episodeNumber = episode['episodeNumber'] ??
        episode['episode_number'] ??
        episode['number'];
    final episodeTitle = episode['title']?.toString() ??
        episode['name']?.toString() ?? episodeMedia.title;
    final activityLabel =
        "Watching ${media.title} Season ${seasonNumber ?? '?'} Episode ${episodeNumber ?? '?'}: $episodeTitle";

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/app/player'),
        builder: (_) {
          return PlayerScreen(
            media: episodeMedia,
            activityLabel: activityLabel,
          );
        },
      ),
    );
  }

  MediaItem? _mediaFromEpisode(
    Map<String, dynamic> episode,
  ) {
    final id = episode['id']?.toString();

    final title = episode['title']?.toString() ??
        episode['name']?.toString();

    if (id == null ||
        id.trim().isEmpty ||
        title == null ||
        title.trim().isEmpty) {
      return null;
    }

    final imageUrl = episode['imageUrl']?.toString() ??
        episode['posterUrl']?.toString();

    final description =
        episode['description']?.toString();

    final year = _integerValue(
      episode['releaseYear'] ?? episode['year'],
    );

    double? rating;

    final rawRating = episode['rating'];

    if (rawRating is num) {
      rating = rawRating.toDouble();
    } else if (rawRating != null) {
      rating = double.tryParse(
        rawRating.toString(),
      );
    }

    final trailerUrl =
        episode['trailerUrl']?.toString();

    final ratingReason =
        episode['ratingReason']?.toString();

    return MediaItem(
      id: id,
      title: title,
      type: 'episode',
      imageUrl: imageUrl,
      description: description,
      releaseYear: year,
      rating: rating,
      ratingReason: ratingReason,
      trailerUrl: trailerUrl,
      playbackUrl: (episode['playbackUrl'] ?? episode['streamingUrl'] ?? episode['streamUrl'] ?? episode['url'])?.toString(),
    );
  }

  // ===========================================================================
  // POSTER
  // ===========================================================================

  /// Performs `_buildPoster` for this feature. Update this documentation when its contract changes.
  Widget _buildPoster() {
    switch (customization.posterStyle) {
      case 'Full Screen':
        return _buildFullScreenPoster();

      case 'Compact':
        return _buildCompactPoster();

      case 'Side':
        return _buildSidePoster();

      case 'Standard':
      default:
        return _buildStandardPoster();
    }
  }

  /// Performs `_buildStandardPoster` for this feature. Update this documentation when its contract changes.
  Widget _buildStandardPoster() {
    final width = customization.posterSize == 'Small'
        ? 220.0
        : customization.posterSize == 'Large'
            ? 390.0
            : 300.0;

    final alignment = customization.posterPosition == 'Left'
        ? Alignment.centerLeft
        : customization.posterPosition == 'Right'
            ? Alignment.centerRight
            : Alignment.center;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: _posterImage(),
            ),
          ),
        ),
      ),
    );
  }

  /// Performs `_buildFullScreenPoster` for this feature. Update this documentation when its contract changes.
  Widget _buildFullScreenPoster() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .62,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _posterImage(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .15),
                      Colors.black.withValues(alpha: .90),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Text(
                  media.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_buildCompactPoster` for this feature. Update this documentation when its contract changes.
  Widget _buildCompactPoster() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SizedBox(
          width: 210,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _posterImage(),
            ),
          ),
        ),
      ),
    );
  }

  /// Performs `_buildSidePoster` for this feature. Update this documentation when its contract changes.
  Widget _buildSidePoster() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _posterImage(),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _buildSidePosterInfo(),
          ),
        ],
      ),
    );
  }

  /// Performs `_buildSidePosterInfo` for this feature. Update this documentation when its contract changes.
  Widget _buildSidePosterInfo() {
    final alignment = _textAlignment();

    return Column(
      crossAxisAlignment: _crossAxisAlignment(),
      children: [
        Text(
          media.title,
          textAlign: alignment,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        _buildSmallMetadata(),
      ],
    );
  }

  /// Prefers the user's/catalog artwork and falls back to TMDB artwork if the
  /// local image is missing or fails to load.
  Widget _posterImage() {
    final urls = <String>[];
    final selectedUrl = CinematicTitleMetadataService.imageUrl(_selectedPosterPath, size: 'w500') ?? '';
    final catalogUrl = media.imageUrl?.trim() ?? '';
    final tmdbUrl = _providerTitleMetadata?.posterUrl ?? '';
    if (selectedUrl.isNotEmpty) urls.add(selectedUrl);
    if (catalogUrl.isNotEmpty && !urls.contains(catalogUrl)) urls.add(catalogUrl);
    if (tmdbUrl.isNotEmpty && !urls.contains(tmdbUrl)) urls.add(tmdbUrl);
    return _posterFromUrls(urls, 0);
  }

  Widget _posterFromUrls(List<String> urls, int index) {
    if (index >= urls.length) return _posterPlaceholder();
    return Image.network(
      urls[index],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _posterFromUrls(urls, index + 1),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            _posterPlaceholder(),
            const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }

  /// Performs `_posterPlaceholder` for this feature. Update this documentation when its contract changes.
  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF171717),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white30,
          size: 70,
        ),
      ),
    );
  }

  // ===========================================================================
  // TITLE
  // ===========================================================================

  /// Performs `_buildTitle` for this feature. Update this documentation when its contract changes.
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: CinematicTitle(
        media: media,
        placement: CinematicTitlePlacement.detail,
        textAlign: _textAlignment(),
        maxWidth: 680,
        height: MediaQuery.sizeOf(context).width < 600 ? 76 : 96,
      ),
    );
  }

  // ===========================================================================
  // METADATA
  // ===========================================================================

  /// Performs `_buildMetadata` for this feature. Update this documentation when its contract changes.
  Widget _buildMetadata() {
    final pills = <Widget>[];

    if (customization.showReleaseYear && media.displayYearLabel != null) {
      pills.add(_metadataPill(
        Icons.calendar_today_outlined,
        media.displayYearLabel!,
      ));
    }
    if (media.displayEditionLabel != null) {
      pills.add(_metadataPill(Icons.movie_filter_outlined, media.displayEditionLabel!));
    }
    if (_displaySeasonCount != null) {
      final count = _displaySeasonCount!;
      pills.add(_metadataPill(Icons.live_tv_outlined,
          '$count ${count == 1 ? 'Season' : 'Seasons'}'));
    }
    if (!media.isSeries && media.editionReleaseYear != null &&
        media.releaseYear != null && media.editionReleaseYear != media.releaseYear) {
      pills.add(_metadataPill(Icons.history_rounded, 'Original ${media.releaseYear}'));
    }

    if (customization.showRating &&
        media.rating != null) {
      pills.add(
        _metadataPill(
          Icons.star_rounded,
          media.rating!.toStringAsFixed(1),
        ),
      );
    }

    final contentRatingValue = contentRating;
    if (customization.showContentRating && contentRatingValue != null) {
      pills.add(
        _metadataPill(Icons.shield_outlined, contentRatingValue),
      );
    }

    final runtimeValue = runtime;
    if (customization.showRuntime && runtimeValue != null) {
      pills.add(
        _metadataPill(Icons.schedule_outlined, runtimeValue),
      );
    }

    final provider = _providerTitleMetadata;
    final voteAverage = provider?.voteAverage;
    final voteCount = provider?.voteCount ?? 0;
    if (voteAverage != null && voteAverage > 0) {
      final votes = voteCount > 0 ? ' · ${_formatProviderInteger(voteCount)} votes' : '';
      pills.add(_metadataPill(Icons.star_rounded, 'TMDB ${voteAverage.toStringAsFixed(1)}/10$votes'));
    }

    final releaseDate = provider?.releaseDate?.trim();
    if (provider != null && releaseDate != null && releaseDate.isNotEmpty) {
      pills.add(_metadataPill(
        Icons.event_available_outlined,
        '${provider.isTv ? 'Premiere' : 'Release'} $releaseDate',
      ));
      if (provider.isTv) {
        final startYear = int.tryParse(releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '');
        final lastDate = provider.lastAirDate?.trim() ?? '';
        final endYear = int.tryParse(lastDate.length >= 4 ? lastDate.substring(0, 4) : '');
        final normalizedStatus = (provider.status ?? '').trim().toLowerCase();
        final ongoing = const <String>{'returning series', 'in production', 'planned', 'pilot'}.contains(normalizedStatus);
        final runLabel = startYear == null
            ? null
            : (ongoing ? '$startYear–Present' : (endYear != null && endYear > startYear ? '$startYear–$endYear' : '$startYear'));
        if (runLabel != null && runLabel != media.displayYearLabel) {
          pills.add(_metadataPill(Icons.live_tv_outlined, 'Series run $runLabel'));
        }
      }
    }

    final originalTitle = provider?.originalTitle?.trim();
    if (originalTitle != null && originalTitle.isNotEmpty && originalTitle.toLowerCase() != media.title.trim().toLowerCase()) {
      pills.add(_metadataPill(Icons.translate_rounded, 'Original: $originalTitle'));
    }
    final budget = provider?.budget;
    if (budget != null && budget > 0) {
      pills.add(_metadataPill(Icons.payments_outlined, 'Budget ${_formatProviderMoney(budget)}'));
    }
    final revenue = provider?.revenue;
    if (revenue != null && revenue > 0) {
      pills.add(_metadataPill(Icons.account_balance_wallet_outlined, 'Revenue ${_formatProviderMoney(revenue)}'));
    }
    final status = provider?.status?.trim();
    if (status != null && status.isNotEmpty) {
      pills.add(_metadataPill(Icons.info_outline_rounded, status));
    }
    final originalLanguage = provider?.originalLanguage;
    if (originalLanguage != null && originalLanguage.trim().isNotEmpty) {
      pills.add(_metadataPill(Icons.language_rounded, 'Language ${_providerLanguageName(originalLanguage)}'));
    }
    final tagline = provider?.tagline?.trim();
    if (tagline != null && tagline.isNotEmpty) {
      pills.add(_metadataPill(Icons.format_quote_rounded, tagline));
    }

    final linkedGenres = _cleanCreditNames(<String>[
      ...media.genres,
      if (provider != null) ...provider.genres,
    ]);
    final linkedTags = _cleanCreditNames(<String>[
      ...media.tags,
      if (provider != null) ...provider.keywords,
    ]);
    final genrePills = linkedGenres.take(12).map((value) => _metadataPill(Icons.category_outlined, value)).toList(growable: false);
    final tagPills = linkedTags.take(12).map((value) => _metadataPill(Icons.sell_outlined, value)).toList(growable: false);

    if (pills.isEmpty && genrePills.isEmpty && tagPills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: _crossAxisAlignment(),
        children: [
          if (pills.isNotEmpty)
            Wrap(alignment: _wrapAlignment(), spacing: 8, runSpacing: 8, children: pills),
          if (genrePills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(alignment: _metadataSectionAlignment(customization.titleAlignment), child: const Text('Genres', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))),
            const SizedBox(height: 5),
            Wrap(alignment: _wrapAlignment(), spacing: 8, runSpacing: 8, children: [
              ...genrePills,
              if (linkedGenres.length > 12) _metadataPill(Icons.more_horiz_rounded, '+ ${linkedGenres.length - 12} more genres'),
            ]),
          ],
          if (tagPills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(alignment: _metadataSectionAlignment(customization.titleAlignment), child: const Text('Tags', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))),
            const SizedBox(height: 5),
            Wrap(alignment: _wrapAlignment(), spacing: 8, runSpacing: 8, children: [
              ...tagPills,
              if (linkedTags.length > 12) _metadataPill(Icons.more_horiz_rounded, '+ ${linkedTags.length - 12} more tags'),
            ]),
          ],
        ],
      ),
    );
  }

  /// Performs `_buildSmallMetadata` for this feature. Update this documentation when its contract changes.
  Widget _buildSmallMetadata() {
    final items = <String>[];

    if (customization.showReleaseYear && media.displayYearLabel != null) {
      items.add(media.displayYearLabel!);
    }
    if (media.displayEditionLabel != null) items.add(media.displayEditionLabel!);
    if (_displaySeasonCount != null) {
      final count = _displaySeasonCount!;
      items.add('$count ${count == 1 ? 'Season' : 'Seasons'}');
    }

    if (customization.showRating &&
        media.rating != null) {
      items.add(
        '★ ${media.rating!.toStringAsFixed(1)}',
      );
    }

    final contentRatingValue = contentRating;
    if (customization.showContentRating && contentRatingValue != null) {
      items.add(contentRatingValue);
    }

    final runtimeValue = runtime;
    if (customization.showRuntime && runtimeValue != null) {
      items.add(runtimeValue);
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      items.join(' • '),
      textAlign: _textAlignment(),
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 13,
        height: 1.4,
      ),
    );
  }

  /// Performs `_metadataPill` for this feature. Update this documentation when its contract changes.
  Widget _metadataPill(
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

  // ===========================================================================
  // OWNERSHIP
  // ===========================================================================

  /// Performs `_buildOwnership` for this feature. Update this documentation when its contract changes.
  Widget _buildOwnership() {
    final owned = _isCurrentMediaOwned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              owned
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: owned
                  ? Colors.greenAccent
                  : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owned
                        ? 'This title is in your library.'
                        : 'This title is not in your library.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AddedByProfileLabel.forMedia(
                      media,
                      compact: false,
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

  // ===========================================================================
  // DESCRIPTION
  // ===========================================================================

  /// Performs `_buildDescription` for this feature. Update this documentation when its contract changes.
  Widget _buildDescription() {
    final localDescription = media.description?.trim() ?? '';
    final providerDescription = _providerTitleMetadata?.overview.trim() ?? '';
    final description = localDescription.isNotEmpty
        ? localDescription
        : (providerDescription.isNotEmpty ? providerDescription : null);

    if (description == null || description.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        description,
        textAlign: _textAlignment(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.55,
        ),
      ),
    );
  }

  // ===========================================================================
  // PLAY
  // ===========================================================================

  /// Performs `_buttonAlignment` for this feature. Update this documentation when its contract changes.
  Alignment _buttonAlignment() {
    switch (customization.buttonAlignment) {
      case 'Center':
        return Alignment.center;

      case 'Right':
        return Alignment.centerRight;

      case 'Left':
      default:
        return Alignment.centerLeft;
    }
  }

  /// Performs `_buildPlay` for this feature. Update this documentation when its contract changes.
  Widget _buildPlay() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: _buttonAlignment(),
        child: SizedBox(
          width: 420,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (pressedPlay || _selectedEdition == null) ? null : playMedia,
            icon: const Icon(
              Icons.play_arrow_rounded,
            ),
            label: const UniversalText('Play',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TRAILER
  // ===========================================================================

  /// Performs `_buildTrailer` for this feature. Update this documentation when its contract changes.
  Widget _buildTrailer() {
    final provider = _providerTitleMetadata;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: pressedTrailer || !hasTrailer ? null : watchTrailer,
              icon: const Icon(Icons.ondemand_video_outlined),
              label: UniversalText(
                (_randomizeAvailableTrailers && _playableProviderVideos.isNotEmpty)
                    ? 'Play Random Trailer'
                    : ((_selectedDetailsTrailerUrl?.trim().isNotEmpty ?? false)
                        ? 'Play Selected Trailer'
                        : 'Watch Trailer'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (provider != null && provider.videos.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildProviderVideos(provider.videos),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // SHOP
  // ===========================================================================

  /// Opens the marketplace in the context of this movie or TV show.
  Widget _buildShop() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ContextualShopButton.forMedia(context, media),
      ),
    );
  }

  /// Treats a local item as owned when either its ID is owned or the active
  /// profile has the same title/type/year in its library. The title fallback
  /// handles duplicate catalog IDs referring to the same movie or show.
  bool get _isCurrentMediaOwned => RecommendationOwnershipMatcher.isMediaOwned(
        media: media,
        controller: AppController.instance,
      );

  // ===========================================================================
  // REVIEWS
  // ===========================================================================

  /// Opens profile and global reviews for this movie or show.
  Widget _buildReviews() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewsHubScreen(media: media, initialMetadata: _providerTitleMetadata))),
          icon: const Icon(Icons.rate_review_outlined),
          label: const UniversalText('Reviews'),
        ),
      ),
    );
  }

  // ===========================================================================
  // AUDIO / SUBTITLES
  // ===========================================================================

  /// Performs `_buildAudioSubtitles` for this feature. Update this documentation when its contract changes.
  Widget _buildAudioSubtitles() {
    final originalLanguage = OriginalLanguageDefaults.resolveForMedia(media);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (originalLanguage != null ||
              (media.language != null && media.language!.trim().isNotEmpty) ||
              media.audioTracks.isNotEmpty ||
              media.subtitles.isNotEmpty ||
              media.extras.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (originalLanguage != null)
                      Text('Original-language default: ${OriginalLanguageDefaults.displayName(originalLanguage)} (audio and subtitles when available)'),
                    if (media.language != null && media.language!.trim().isNotEmpty)
                      Text('Language: ${media.language}'),
                    if (media.audioTracks.isNotEmpty)
                      Text('Audio: ${media.audioTracks.join(', ')}'),
                    if (media.subtitles.isNotEmpty)
                      Text('Subtitles: ${media.subtitles.join(', ')}'),
                    if (media.extras.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const UniversalText('Extras',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      for (final extra in media.extras) Text('• $extra'),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openAudioSubtitleOptions,
              icon: const Icon(Icons.closed_caption_outlined),
              label: const UniversalText(
                'Audio & Subtitles',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_openAudioSubtitleOptions` for this feature. Update this documentation when its contract changes.
  void _openAudioSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      builder: (_) {
        return AudioSubtitleOptions(
          audioOptions: media.audioTracks,
          subtitleOptions: media.subtitles,
          selectedAudio: selectedAudio,
          subtitlesEnabled: subtitlesEnabled,
          selectedSubtitle: selectedSubtitle,
          onAudioChanged: (value) {
            setState(() {
              selectedAudio = value;
            });
          },
          onSubtitleChanged: (value) {
            setState(() {
              selectedSubtitle = value;
              subtitlesEnabled = value != null;
            });
          },
        );
      },
    );
  }

  // ===========================================================================
  // REACTIONS
  // ===========================================================================

  /// Performs `_buildReactions` for this feature. Update this documentation when its contract changes.
  Widget _buildReactions() {
    final controller = AppController.instance;

    final liked = controller.isLiked(media.id);
    final disliked = controller.isDisliked(media.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: LikeToggleButton(
              liked: liked,
              showLabel: true,
              onPressed: () async {
                final result = await UniversalMediaActions.perform(
                  context: _actionContext(const {
                    UniversalMediaAction.like,
                    UniversalMediaAction.removeReaction,
                  }),
                  action: liked
                      ? UniversalMediaAction.removeReaction
                      : UniversalMediaAction.like,
                  apply: () => setState(() {
                    if (liked) {
                      controller.clearReaction(media.id);
                    } else {
                      controller.likeMedia(media);
                    }
                  }),
                );
                if (result.applied && mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await UniversalMediaActions.perform(
                  context: _actionContext(const {
                    UniversalMediaAction.dislike,
                    UniversalMediaAction.removeReaction,
                  }),
                  action: disliked
                      ? UniversalMediaAction.removeReaction
                      : UniversalMediaAction.dislike,
                  apply: () => setState(() {
                    if (disliked) {
                      controller.clearReaction(media.id);
                    } else {
                      controller.dislikeMedia(media);
                    }
                  }),
                );
              },
              icon: Icon(
                disliked
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
              ),
              label: const UniversalText('Dislike'),
            ),
          ),
        ],
      ),
    );
  }

  UniversalMediaActionContext _actionContext(
    Set<UniversalMediaAction> availableActions,
  ) =>
      UniversalMediaActionContext(
        contentType: media.type,
        contentId: media.id,
        mediaVersionId: media.mediaVersionId,
        profileId: AppController.instance.currentProfile?.id ?? 'local-profile',
        availableActions: availableActions,
      );

  // ===========================================================================
  // CAST & CREW
  // ===========================================================================

  List<String> _cleanCreditNames(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in names) {
      final name = value.trim();
      final key = name.toLowerCase();
      if (name.isNotEmpty && seen.add(key)) result.add(name);
    }
    return result;
  }

  List<String> _mergeCreditNames(
    Iterable<String> catalogNames,
    Iterable<String> providerNames,
  ) =>
      _cleanCreditNames(<String>[...catalogNames, ...providerNames]);

  void _openCatalogEntity(String name, CatalogEntityKind kind) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CatalogEntityDetailsScreen(
          entityName: name,
          kind: kind,
          sourceMedia: media,
          onOpenMedia: (selectedMedia) {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => MediaDetailsScreen(media: selectedMedia),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _castCrewNameRow(
    String label,
    List<String> names, {
    CatalogEntityKind entityKind = CatalogEntityKind.person,
  }) {
    if (names.isEmpty) return const SizedBox.shrink();
    final icon = switch (entityKind) {
      CatalogEntityKind.person => Icons.person_outline_rounded,
      CatalogEntityKind.company => Icons.business_outlined,
      CatalogEntityKind.character => Icons.theater_comedy_outlined,
      CatalogEntityKind.genre => Icons.local_movies_outlined,
      CatalogEntityKind.tag => Icons.sell_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: UniversalText(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final name in names)
                  ActionChip(
                    avatar: entityKind == CatalogEntityKind.person
                        ? CatalogPersonAvatar(
                            name: name,
                            radius: 11,
                            fallbackIcon: icon,
                          )
                        : Icon(icon, size: 15),
                    label: Text(name),
                    onPressed: () => _openCatalogEntity(name, entityKind),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders credits independently from general technical/content information.
  /// Missing credits are called out honestly; the UI never invents names.
  Widget _buildCastCrew() {
    final provider = _providerTitleMetadata;
    final actors = _mergeCreditNames(media.actors, provider?.cast ?? const <String>[]);
    final characters = _mergeCreditNames(media.characters, provider?.characters ?? const <String>[]);
    final directors = _mergeCreditNames(media.directors, provider?.directors ?? const <String>[]);
    final writers = _mergeCreditNames(media.writers, provider?.writers ?? const <String>[]);
    final music = _mergeCreditNames(media.music, provider?.music ?? const <String>[]);
    final hasCredits = actors.isNotEmpty || characters.isNotEmpty ||
        directors.isNotEmpty || writers.isNotEmpty || music.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_2_outlined, size: 21, color: Colors.white70),
                const SizedBox(width: 9),
                Expanded(
                  child: UniversalText(
                    media.type.toLowerCase().contains('album')
                        ? 'Artists & Album Credits'
                        : 'Cast & Crew',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                if (CinematicTitleMetadataService.isConfigured &&
                    _supportsCinematicProviderMetadata)
                  IconButton(
                    tooltip: 'Refresh all TMDB metadata and cast/crew',
                    onPressed: _loadingProviderMetadata ? null : _loadProviderTitleMetadata,
                    icon: _loadingProviderMetadata
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, color: Colors.white70),
                  ),
              ],
            ),
            if (_loadingProviderMetadata) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              const UniversalText('Checking the exact title match and loading sourced credits…', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
            if (!hasCredits) ...[
              const SizedBox(height: 10),
              UniversalText(
                media.type.toLowerCase().contains('album')
                    ? 'Artist and performer credits are not available for this album yet. Add the artist to the album metadata or import a metadata source.'
                    : (!CinematicTitleMetadataService.isConfigured
                        ? 'Cast and crew credits are not available in the local catalog. Sign in and configure TMDB_API_KEY or TMDB_API_TOKEN in Backend/.env to load sourced cast, director, and writer metadata.'
                        : (_providerMetadataError ?? 'No sourced cast and crew credits are available for this title yet.')),
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
            ] else ...[
              const SizedBox(height: 12),
              if (provider == null && media.tags.contains('catalog-example'))
                const Padding(
                  padding: EdgeInsets.only(bottom: 9),
                  child: UniversalText(
                    'Starter catalog credits for exploring profiles; this is not an exhaustive or provider-verified credits list. Sign in and configure TMDB_API_KEY or TMDB_API_TOKEN in Backend/.env to enrich supported movie/TV titles.',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                  ),
                ),
              if (provider != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: UniversalText('Verified title match from TMDB; credits below are merged with catalog metadata.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              if (actors.isNotEmpty)
                _castCrewNameRow('Cast', actors),
              if (characters.isNotEmpty)
                _castCrewNameRow('Characters', characters, entityKind: CatalogEntityKind.character),
              if (directors.isNotEmpty)
                _castCrewNameRow('Directors', directors),
              if (writers.isNotEmpty)
                _castCrewNameRow('Screenwriters', writers),
              if (music.isNotEmpty)
                _castCrewNameRow(
                  media.type.toLowerCase().contains('album')
                      ? 'Artists / Performers'
                      : 'Music',
                  music,
                ),
              if (_providerMetadataError != null && provider == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_providerMetadataError!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INFORMATION
  // ===========================================================================

  /// Performs `_buildInformation` for this feature. Update this documentation when its contract changes.
  Widget _buildInformation() {
    final rows = <Widget>[];

    if (customization.showReleaseYear && media.displayYearLabel != null) {
      rows.add(_infoRow(
        media.isSeries
            ? 'Series Run'
            : (media.editionReleaseYear != null ? 'Edition Release Year' : 'Release Year'),
        media.displayYearLabel!,
      ));
    }
    if (media.isSeries || const <String>{'movie', 'film'}.contains(media.type.trim().toLowerCase())) {
      final localCountry = media.countryOfOrigin?.trim() ?? '';
      final providerCountry = _providerTitleMetadata?.countryOfOrigin?.trim() ?? '';
      final country = localCountry.isNotEmpty
          ? mediaCountryOriginLabel(media)
          : (providerCountry.isNotEmpty ? providerCountry : 'Country of origin unavailable');
      rows.add(_infoRow('Country of Origin', country));
    }
    if (!media.isSeries && media.editionReleaseYear != null &&
        media.releaseYear != null && media.editionReleaseYear != media.releaseYear) {
      rows.add(_infoRow('Original Release Year', media.releaseYear.toString()));
    }
    if (media.displayEditionLabel != null) {
      rows.add(_infoRow('Edition', media.displayEditionLabel!));
    }
    if (media.editionFeatures.isNotEmpty) {
      rows.add(_infoRow('Edition Includes', media.editionFeatures.join(' • ')));
    }
    if (_displaySeasonCount != null) {
      final count = _displaySeasonCount!;
      rows.add(_infoRow('Seasons', '$count ${count == 1 ? 'Season' : 'Seasons'}'));
    }

    final provider = _providerTitleMetadata;
    if (provider != null) {
      // Core TMDB facts (release date, original title, score, budget, revenue,
      // status, tagline, runtime and original language) now live in the primary
      // Metadata section above the description. Keep this section for actions
      // such as the official website and artwork gallery.
      if (provider.homepage?.trim().isNotEmpty == true) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => _openProviderUrl(provider.homepage!),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Official website'),
          )),
        ));
      }
    }

    final linkedGenres = _cleanCreditNames(<String>[
      ...media.genres,
      if (provider != null) ...provider.genres,
    ]);
    if (linkedGenres.isNotEmpty) {
      rows.add(_castCrewNameRow(
        'Genres',
        linkedGenres,
        entityKind: CatalogEntityKind.genre,
      ));
    }

    final studios = _cleanCreditNames(media.studios);
    if (studios.isNotEmpty) {
      rows.add(_castCrewNameRow(
        'Production Studios',
        studios,
        entityKind: CatalogEntityKind.company,
      ));
    }

    final companies = _cleanCreditNames(media.companies);
    if (companies.isNotEmpty) {
      rows.add(_castCrewNameRow(
        'Companies',
        companies,
        entityKind: CatalogEntityKind.company,
      ));
    }

    final linkedTags = _cleanCreditNames(<String>[...media.tags, if (provider != null) ...provider.keywords]);
    if (linkedTags.isNotEmpty) {
      rows.add(_castCrewNameRow(
        'Tags',
        linkedTags,
        entityKind: CatalogEntityKind.tag,
      ));
    }

    final relatedExtras = AppController.instance.library
        .where((item) => item.parentMediaId == media.id)
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (relatedExtras.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 12),
        child: Card(
          color: const Color(0xFF151515),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extras & Special Features (${relatedExtras.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Linked deleted scenes, featurettes, trailers, alternate cuts and commentary items appear here. Playback requires a connected media-server URL.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                const SizedBox(height: 8),
                for (final extra in relatedExtras)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie_filter_outlined, color: Colors.white70),
                    title: Text(extra.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(<String>[
                      ...extra.tags.where((tag) => tag.toLowerCase() != 'disc extra'),
                      if (extra.releaseYear != null) extra.releaseYear.toString(),
                    ].take(3).join(' · ')),
                    trailing: Icon(extra.playbackUrl?.trim().isNotEmpty == true ? Icons.play_circle_outline_rounded : Icons.info_outline_rounded, color: extra.playbackUrl?.trim().isNotEmpty == true ? Colors.greenAccent : Colors.white54),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: extra))),
                  ),
              ],
            ),
          ),
        ),
      ));
    }
    if (media.parentMediaId?.trim().isNotEmpty == true) {
      MediaItem? linkedParent;
      for (final candidate in AppController.instance.library) {
        if (candidate.id == media.parentMediaId) {
          linkedParent = candidate;
          break;
        }
      }
      if (linkedParent != null) {
        final parent = linkedParent;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: parent))),
            icon: const Icon(Icons.subdirectory_arrow_left_rounded),
            label: Text('Bonus content for ${parent.title}'),
          ),
        ));
      }
    }

    // Only display content advisories supplied by the catalog/importer.
    final contentAdvisories = firstMetadataValue([
      'contentAdvisories',
      'content_advisories',
      'contentWarnings',
      'content_warnings',
      'parentalGuidance',
      'parental_guidance',
      'maturityReasons',
      'maturity_reasons',
      'ratingDescriptors',
      'rating_descriptors',
    ]);
    if (contentAdvisories != null && contentAdvisories.trim().isNotEmpty) {
      rows.add(_infoRow('Content Advisories', contentAdvisories));
    }

    if (customization.showRating &&
        media.rating != null) {
      rows.add(
        _infoRow(
          'Rating',
          media.rating!.toStringAsFixed(1),
        ),
      );

      if (media.ratingReason != null &&
          media.ratingReason!.trim().isNotEmpty) {
        rows.add(
          _infoRow(
            'Why this rating',
            media.ratingReason!,
          ),
        );
      }
    }

    final contentRatingValue = contentRating;
    if (customization.showContentRating && contentRatingValue != null) {
      rows.add(_infoRow('Content Rating', contentRatingValue));
    }

    final runtimeValue = runtime;
    if (customization.showRuntime && runtimeValue != null) {
      rows.add(_infoRow('Runtime', runtimeValue));
    }

    if (media.discType != null && media.discType!.trim().isNotEmpty) {
      rows.add(
        _infoRow(
          'Disc Type',
          media.discType!,
        ),
      );
    }

    if (media.discRegion != null && media.discRegion!.trim().isNotEmpty) {
      rows.add(
        _infoRow(
          'Region',
          media.discRegion!,
        ),
      );
    }

    if (media.discCollectionTitle != null && media.discCollectionTitle!.trim().isNotEmpty) {
      rows.add(
        _infoRow(
          'Disc Collection',
          media.discCollectionTitle!,
        ),
      );
    }

    if (media.discNumber != null) {
      rows.add(
        _infoRow(
          'Disc Number',
          media.discNumber!.toString(),
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UniversalText('Information',
              textAlign: _informationTextAlign(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  /// Performs `_infoRow` for this feature. Update this documentation when its contract changes.
  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIBRARY
  // ===========================================================================

  /// Performs `_buildLibrary` for this feature. Update this documentation when its contract changes.
  Widget _buildLibrary() {
    final controller = AppController.instance;
    final owned = controller.isOwned(media.id);

    final addableCollections = controller.collections
        .where((c) => !c.isAutomatic && c.canCurrentProfileAdd())
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  if (owned) {
                    await controller.removeFromLibrary(media.id);
                  } else {
                    await controller.addToLibrary(media);
                  }
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(owned
                          ? 'Removed from this profile’s library.'
                          : 'Added to this profile’s library.'),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save this library change: ${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                owned
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
              ),
              label: Text(
                owned
                    ? 'Remove from Library'
                    : 'Add to Library',
              ),
            ),
          ),
          if (addableCollections.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showAddToCollection,
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const UniversalText('Add to Collection',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Performs `_showAddToCollection` for this feature. Update this documentation when its contract changes.
  void _showAddToCollection() {
    final controller = AppController.instance;
    final collections = controller.collections
        .where((c) => !c.isAutomatic && c.canCurrentProfileAdd())
        .toList();

    if (collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UniversalText('No collections are available for this profile.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            Text(
              'Add \'${media.title}\' to Collection',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const UniversalText('Choose a collaborative or private custom collection.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            for (final collection in collections)
              ListTile(
                leading: Icon(
                  collection.mediaIds.contains(media.id)
                      ? Icons.check_circle
                      : Icons.collections_bookmark_outlined,
                ),
                title: Text(collection.name),
                subtitle: Text(
                  collection.mediaIds.contains(media.id)
                      ? 'Already in this collection'
                      : collection.isShared
                          ? 'Shared collection'
                          : 'Private collection',
                ),
                enabled: !collection.mediaIds.contains(media.id) &&
                    collection.canCurrentProfileAdd(),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await UniversalMediaActions.perform(
                    context: _actionContext(const {
                      UniversalMediaAction.addToCollection,
                    }),
                    action: UniversalMediaAction.addToCollection,
                    targetId: collection.id,
                    apply: () => controller.addToCollection(
                      collection.id,
                      media.id,
                    ),
                  );
                  if (!result.applied) return;
                  if (!mounted) return;
                  navigator.pop();
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(content: UniversalText('Added to ${collection.name}.')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  /// Performs `playMedia` for this feature. Update this documentation when its contract changes.
  void playMedia() {
    setState(() {
      pressedPlay = true;
    });

    Navigator.of(context)
        .push(
      PageRouteBuilder(
          settings: const RouteSettings(name: '/app/player'),
          pageBuilder: (_, __, ___) {
          return PlayerScreen(
            media: _selectedEdition ?? media,
          );
        },
        transitionsBuilder: (
          _,
          animation,
          __,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          pressedPlay = false;
        });
      }
    });
  }

  /// Performs `startGroupWatch` for this feature. Update this documentation when its contract changes.
  void startGroupWatch() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const UniversalText('Watch Together'),
        content: const UniversalText('Who do you want to watch with?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchGroupWatch();
            },
            child: const UniversalText('People in this account',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareGroupWatch();
            },
            icon: const Icon(
              Icons.share_outlined,
            ),
            label: const UniversalText('Other people',
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_launchGroupWatch` for this feature. Update this documentation when its contract changes.
  void _launchGroupWatch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupWatchScreen(
          media: media,
        ),
      ),
    );
  }

  /// Performs `_shareGroupWatch` for this feature. Update this documentation when its contract changes.
  void _shareGroupWatch() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const SizedBox(
                width: double.infinity,
                child: UniversalText('Invite with…',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              for (final app in [
                'Messenger',
                'WhatsApp',
                'Telegram',
                'Instagram',
                'iMessage',
              ])
                ActionChip(
                  label: Text(app),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: UniversalText('Group Watch invite ready for $app.',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `watchTrailer` for this feature. Update this documentation when its contract changes.
  void watchTrailer() {
    final selectedUrl = _selectedDetailsTrailerUrl?.trim() ?? '';
    final catalogUrl = media.trailerUrl?.trim() ?? '';
    var url = selectedUrl.isNotEmpty ? selectedUrl : catalogUrl;
    String? randomTitle;
    if (_randomizeAvailableTrailers && _playableProviderVideos.isNotEmpty) {
      final pool = _playableProviderVideos;
      final picked = pool[math.Random().nextInt(pool.length)];
      url = picked.url ?? url;
      randomTitle = picked.name;
    }
    if (url.isEmpty) return;
    if (randomTitle != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Random trailer: $randomTitle')),
      );
    }

    setState(() {
      pressedTrailer = true;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) {
          return TrailerPlayerScreen(
            trailerUrl: url,
            title: '${media.title} Trailer',
          );
        },
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          pressedTrailer = false;
        });
      }
    });
  }

  // ===========================================================================
  // ALIGNMENT
  // ===========================================================================

  TextAlign _textAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return TextAlign.center;

      case 'Right':
        return TextAlign.right;

      case 'Left':
      default:
        return TextAlign.left;
    }
  }

  /// Performs `_crossAxisAlignment` for this feature. Update this documentation when its contract changes.
  CrossAxisAlignment _crossAxisAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return CrossAxisAlignment.center;

      case 'Right':
        return CrossAxisAlignment.end;

      case 'Left':
      default:
        return CrossAxisAlignment.start;
    }
  }

  TextAlign _informationTextAlign() {
    switch (customization.informationAlignment) {
      case 'Center':
        return TextAlign.center;

      case 'Right':
        return TextAlign.right;

      case 'Left':
      default:
        return TextAlign.left;
    }
  }

  /// Performs `_wrapAlignment` for this feature. Update this documentation when its contract changes.
  WrapAlignment _wrapAlignment() {
    switch (customization.titleAlignment) {
      case 'Center':
        return WrapAlignment.center;

      case 'Right':
        return WrapAlignment.end;

      case 'Left':
      default:
        return WrapAlignment.start;
    }
  }


  // ===========================================================================
  // MEDIA METADATA
  // ===========================================================================

  Map<String, dynamic> get mediaJson {
    try {
      return media.toJson();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? firstMetadataValue(
    List<String> keys,
  ) {
    final json = mediaJson;

    for (final key in keys) {
      final value = json[key];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  String? get contentRating {
    return firstMetadataValue([
      'contentRating',
      'content_rating',
      'ratingCode',
      'ageRating',
      'certificate',
      'certification',
    ]);
  }

  String? get runtime {
    final value = firstMetadataValue([
      'runtime',
      'runtimeMinutes',
      'duration',
      'durationMinutes',
    ]) ?? _providerTitleMetadata?.runtimeMinutes?.toString();

    if (value == null) {
      return null;
    }

    final minutes = int.tryParse(value);

    if (minutes == null) {
      return value;
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  bool get hasTrailer {
    final selectedUrl = _selectedDetailsTrailerUrl?.trim() ?? '';
    final catalogUrl = media.trailerUrl?.trim() ?? '';
    return selectedUrl.isNotEmpty || catalogUrl.isNotEmpty ||
        _playableProviderVideos.isNotEmpty;
  }
}

// =============================================================================
// SEASON BUTTON
// =============================================================================

class _SeasonButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SeasonButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? Colors.white
              : Colors.white.withValues(
                  alpha: .045,
                ),
          foregroundColor: selected
              ? Colors.black
              : Colors.white,
          side: BorderSide(
            color: selected
                ? Colors.white
                : Colors.white.withValues(
                    alpha: .12,
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EPISODE CARD
// =============================================================================

class _EpisodeCard extends StatefulWidget {
  final Map<String, dynamic> episode;
  final VoidCallback onPlay;

  const _EpisodeCard({
    required this.episode,
    required this.onPlay,
  });

  @override
  State<_EpisodeCard> createState() =>
      _EpisodeCardState();
}

/// Implements the `_EpisodeCardState` class for this feature or UI component.
class _EpisodeCardState extends State<_EpisodeCard> {
  bool hovering = false;

  String get title {
    return widget.episode['title']?.toString() ??
        widget.episode['name']?.toString() ??
        'Episode';
  }

  String? get description {
    final value =
        widget.episode['description']?.toString();

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  String? get imageUrl {
    final value =
        widget.episode['imageUrl']?.toString() ??
            widget.episode['posterUrl']?.toString();

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value;
  }

  String? get episodeNumber {
    final number = widget.episode['number'] ??
        widget.episode['episodeNumber'] ??
        widget.episode['episode_number'];

    if (number == null) {
      return null;
    }

    return number.toString();
  }

  String? get airDate {
    final value = (widget.episode['airDate'] ?? widget.episode['air_date'])
        ?.toString()
        .trim();
    if (value == null || value.isEmpty) return null;
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  String? get runtime {
    final value =
        widget.episode['runtime'] ??
            widget.episode['runtimeMinutes'] ??
            widget.episode['duration'];

    if (value == null) {
      return null;
    }

    final minutes = int.tryParse(
      value.toString(),
    );

    if (minutes == null) {
      return value.toString();
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  /// Performs `_showEpisodeLabel` for this feature. Update this documentation when its contract changes.
  bool _showEpisodeLabel() => true;

  /// Always identifies the season/episode separately from the title. The
  /// preference controls wording, but the episode number remains visible.
  String _episodeLabel() {
    final seasonNumber = widget.episode['seasonNumber'] ??
        widget.episode['season_number'] ??
        widget.episode['season'];
    final n = episodeNumber ?? '?';
    final season = seasonNumber?.toString() ?? '?';
    switch (DetailsCustomizationStore.settingsFor(
      AppController.instance.currentProfile,
    ).episodeNaming) {
      case 'Season X, Episode Y':
        return 'SEASON $season • EPISODE $n';
      case 'Both':
        return 'S$season E$n';
      case 'Actual Title':
      default:
        return 'S${season.padLeft(2, '0')} • E${n.padLeft(2, '0')}';
    }
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hovering
                ? Colors.white.withValues(
                    alpha: .075,
                  )
                : Colors.white.withValues(
                    alpha: .035,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering
                  ? Colors.white.withValues(
                      alpha: .15,
                    )
                  : Colors.white.withValues(
                      alpha: .06,
                    ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                height: 85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: imageUrl == null
                      ? Container(
                          color: const Color(0xFF202020),
                          child: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white38,
                            size: 34,
                          ),
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: const Color(0xFF202020),
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white38,
                                size: 34,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (_showEpisodeLabel())
                      Text(
                        _episodeLabel(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (runtime != null || airDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [if (airDate != null) 'Aired $airDate', if (runtime != null) runtime!].join('  •  '),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: hovering ? .16 : .09,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.episode['metadataOnly'] == true
                      ? Icons.info_outline_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TRAILER PLAYER
// =============================================================================

class TrailerPlayerScreen extends StatefulWidget {
  final String trailerUrl;
  final String title;

  const TrailerPlayerScreen({
    super.key,
    required this.trailerUrl,
    required this.title,
  });

  @override
  State<TrailerPlayerScreen> createState() =>
      _TrailerPlayerScreenState();
}

/// Implements the `_TrailerPlayerScreenState` class for this feature or UI component.
class _TrailerPlayerScreenState
    extends State<TrailerPlayerScreen> {
  YoutubePlayerController? _controller;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    final videoId =
        YoutubePlayerController.convertUrlToId(
      widget.trailerUrl,
    );

    if (videoId != null && videoId.isNotEmpty) {
      _controller =
          YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
    }
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _controller == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: UniversalText('Unable to play this trailer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              )
            : YoutubePlayer(
                controller: _controller!,
                aspectRatio: 16 / 9,
              ),
      ),
    );
  }
}


/// Resolves the alignment for metadata section headings. Kept top-level so
/// metadata widgets can use it without relying on a particular State scope.
Alignment _metadataSectionAlignment(String titleAlignment) {
  switch (titleAlignment) {
    case 'Center':
      return Alignment.center;
    case 'Right':
      return Alignment.centerRight;
    case 'Left':
    default:
      return Alignment.centerLeft;
  }
}
