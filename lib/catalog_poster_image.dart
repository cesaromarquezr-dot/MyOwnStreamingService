// Loads verified TMDB posters for movies/TV or Spotify/Cover Art Archive
// covers for albums only when a user's media server or catalog has no artwork.
import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'core/services/cinematic_title_metadata_service.dart';

class CatalogPosterImage extends StatefulWidget {
  const CatalogPosterImage({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorPlaceholder,
  });

  final MediaItem media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  @override
  State<CatalogPosterImage> createState() => _CatalogPosterImageState();
}

class _CatalogPosterImageState extends State<CatalogPosterImage> {
  // Multiple Home/Movie/TV rails can show the same media. Share the provider
  // lookup so the app does not repeatedly ask TMDB for the same title.
  static final Map<String, Future<CinematicTitleMetadata?>> _lookupCache =
      <String, Future<CinematicTitleMetadata?>>{};
  static final Map<String, Future<String?>> _albumCoverLookupCache =
      <String, Future<String?>>{};

  late String _imageUrl;
  late String _mediaKey;
  bool _fallbackAttempted = false;
  bool _providerLookupStarted = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.media.imageUrl?.trim() ?? '';
    _mediaKey = _keyFor(widget.media);
    AppController.instance.addListener(_onAppControllerChanged);
    _startProviderLookupIfReady();
  }

  void _onAppControllerChanged() {
    // A card can be mounted before login. Retry the lookup after authentication
    // changes without requiring the user to leave and re-enter the Home page.
    _startProviderLookupIfReady();
  }

  void _startProviderLookupIfReady() {
    if (!mounted || _providerLookupStarted || _imageUrl.isNotEmpty ||
        !CinematicTitleMetadataService.isConfigured) {
      return;
    }
    _providerLookupStarted = true;
    unawaited(_loadPoster());
  }

  @override
  void dispose() {
    AppController.instance.removeListener(_onAppControllerChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogPosterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _keyFor(widget.media);
    if (nextKey != _mediaKey) {
      _mediaKey = nextKey;
      _fallbackAttempted = false;
      _providerLookupStarted = false;
      _imageUrl = widget.media.imageUrl?.trim() ?? '';
      _startProviderLookupIfReady();
    } else if (!_fallbackAttempted && _imageUrl.isEmpty &&
        (widget.media.imageUrl?.trim().isNotEmpty ?? false)) {
      _imageUrl = widget.media.imageUrl!.trim();
    }
  }

  static String _keyFor(MediaItem media) =>
      '${media.id}|${media.type}|${media.title}|${media.isSeries}|${media.releaseYear ?? media.seriesStartYear ?? ''}|${media.music.join(',')}';

  Future<void> _loadPoster() async {
    final media = widget.media;
    final type = media.type.trim().toLowerCase();
    final key = _keyFor(media);
    if (!CinematicTitleMetadataService.isConfigured) return;

    if (type.contains('album') || type == 'soundtrack') {
      try {
        final cover = await _albumCoverLookupCache.putIfAbsent(
          key,
          () => _lookupAlbumCover(media),
        );
        if (cover == null || cover.isEmpty) return;
        if (mounted && _mediaKey == key && _imageUrl.isEmpty) {
          setState(() => _imageUrl = cover);
        }
        unawaited(AppController.instance.mergeProviderTitleCredits(
          mediaId: media.id,
          posterUrl: cover,
          music: media.music,
        ));
      } catch (_) {
        // Keep the safe placeholder when no exact album artwork is available.
      }
      return;
    }

    final isMovie = type == 'movie';
    final isTv = media.isSeries;
    if (!isMovie && !isTv) return;

    final lookup = _lookupCache.putIfAbsent(
      key,
      () => CinematicTitleMetadataService.lookupTitle(
        title: media.title,
        isTv: isTv,
        year: media.releaseYear ?? media.seriesStartYear,
      ),
    );

    try {
      final metadata = await lookup;
      final poster = metadata?.posterUrl?.trim() ?? '';
      if (poster.isEmpty) return;
      if (mounted && _mediaKey == key && _imageUrl.isEmpty) {
        setState(() => _imageUrl = poster);
      }
      // Persist the verified poster/credits for normal library entries. The
      // merge method never replaces existing custom artwork or playback URLs.
      unawaited(AppController.instance.mergeProviderTitleCredits(
        mediaId: media.id,
        posterUrl: poster,
        actors: metadata?.cast ?? const <String>[],
        characters: metadata?.characters ?? const <String>[],
        directors: metadata?.directors ?? const <String>[],
        writers: metadata?.writers ?? const <String>[],
        music: metadata?.music ?? const <String>[],
      ));
    } catch (_) {
      // Provider lookup is best effort; keep the placeholder and leave browsing
      // and opening the normal details page fully functional.
    }
  }

  static Future<String?> _lookupAlbumCover(MediaItem media) async {
    final title = media.title.trim();
    if (title.isEmpty) return null;
    final artist = media.music.map((value) => value.trim()).firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => '',
    );
    // Both provider adapters receive this search string. A plain, exact-title
    // query works with Spotify's and MusicBrainz's different query syntaxes;
    // artist/year are used below to rank exact-title matches safely.
    final query = title;
    final payload = await AppController.instance.backendApi.searchMusicCatalog(
      query,
      type: 'album',
      limit: 10,
    );
    final spotify = payload['spotify'] is Map
        ? Map<String, dynamic>.from(payload['spotify'] as Map)
        : <String, dynamic>{};
    final spotifyAlbums = spotify['albums'] is List
        ? (spotify['albums'] as List).whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
        : <Map<String, dynamic>>[];
    String normalize(String value) => value.toLowerCase().trim().replaceAll(
      RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"),
      '',
    );
    final wantedTitle = normalize(title);
    final candidate = spotifyAlbums.where((row) => normalize(row['title']?.toString() ?? '') == wantedTitle).toList();
    if (candidate.isNotEmpty) {
      final wantedArtist = normalize(artist);
      candidate.sort((a, b) {
        final aArtist = normalize(a['artist']?.toString() ?? '');
        final bArtist = normalize(b['artist']?.toString() ?? '');
        final aArtistScore = wantedArtist.isNotEmpty && aArtist.contains(wantedArtist) ? 0 : 1;
        final bArtistScore = wantedArtist.isNotEmpty && bArtist.contains(wantedArtist) ? 0 : 1;
        if (aArtistScore != bArtistScore) return aArtistScore.compareTo(bArtistScore);
        final year = media.releaseYear;
        if (year != null) {
          final aYearScore = (a['releaseDate']?.toString() ?? '').startsWith('$year') ? 0 : 1;
          final bYearScore = (b['releaseDate']?.toString() ?? '').startsWith('$year') ? 0 : 1;
          if (aYearScore != bYearScore) return aYearScore.compareTo(bYearScore);
        }
        return 0;
      });
      for (final row in candidate) {
        final image = row['imageUrl']?.toString().trim() ?? '';
        if (image.startsWith('https://')) return image;
        final images = row['images'];
        if (images is List) {
          for (final raw in images.whereType<Map>()) {
            final value = raw['url']?.toString().trim() ?? '';
            if (value.startsWith('https://')) return value;
          }
        }
      }
    }

    // MusicBrainz results can still provide community art through Cover Art Archive.
    final musicBrainz = payload['musicBrainz'] is Map
        ? Map<String, dynamic>.from(payload['musicBrainz'] as Map)
        : <String, dynamic>{};
    final groups = musicBrainz['releaseGroups'] is List
        ? (musicBrainz['releaseGroups'] as List).whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList()
        : <Map<String, dynamic>>[];
    final exactGroups = groups.where((group) => normalize(group['title']?.toString() ?? '') == wantedTitle).toList();
    exactGroups.sort((a, b) {
      final wantedArtist = normalize(artist);
      final aArtist = normalize(a['artist']?.toString() ?? '');
      final bArtist = normalize(b['artist']?.toString() ?? '');
      final aScore = wantedArtist.isNotEmpty && aArtist.contains(wantedArtist) ? 0 : 1;
      final bScore = wantedArtist.isNotEmpty && bArtist.contains(wantedArtist) ? 0 : 1;
      return aScore.compareTo(bScore);
    });
    for (final group in exactGroups) {
      final image = group['coverArtUrl']?.toString().trim() ?? '';
      if (image.startsWith('https://')) return image;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl.trim();
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        _scheduleProviderFallback();
        return widget.errorPlaceholder ?? _placeholder();
      },
    );
  }

  void _scheduleProviderFallback() {
    if (_fallbackAttempted) return;
    _fallbackAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _imageUrl = '');
      _providerLookupStarted = false;
      _startProviderLookupIfReady();
    });
  }

  Widget _placeholder() => widget.placeholder ?? SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF242424),
          child: Center(
            child: Icon(Icons.movie_outlined, color: Colors.white54, size: 32),
          ),
        ),
      );
}
