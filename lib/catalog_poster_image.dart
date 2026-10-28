// Loads verified TMDB posters for movies/TV or Spotify/Cover Art Archive
// covers for albums only when a user's media server or catalog has no artwork.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'app_core.dart';
import 'core/services/cinematic_title_metadata_service.dart';
import 'media_artwork_auto_resolver.dart';

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
    final key = _keyFor(media);
    if (!CinematicTitleMetadataService.isConfigured) return;

    try {
      // Reuse previously verified metadata immediately after an app restart.
      // This avoids a backend catalog round-trip for every missing local poster.
      final savedPoster = await MediaArtworkAutoResolver.readAutoPosterUrl(media.id);
      if (savedPoster != null && savedPoster.isNotEmpty) {
        if (mounted && _mediaKey == key && _imageUrl.isEmpty) {
          setState(() => _imageUrl = savedPoster);
        }
        return;
      }
      final resolved = await MediaArtworkAutoResolver.resolveMedia(media);
      final poster = resolved?.posterUrl?.trim() ?? '';
      if (poster.isEmpty) return;
      if (mounted && _mediaKey == key && _imageUrl.isEmpty) {
        setState(() => _imageUrl = poster);
      }
      final metadata = resolved?.titleMetadata;
      // Persist a verified poster and any exact-match TMDB credits without
      // replacing custom artwork or changing playback URLs.
      unawaited(AppController.instance.mergeProviderTitleCredits(
        mediaId: media.id,
        posterUrl: poster,
        actors: metadata?.cast ?? const <String>[],
        characters: metadata?.characters ?? const <String>[],
        directors: metadata?.directors ?? const <String>[],
        writers: metadata?.writers ?? const <String>[],
        music: metadata?.music ?? const <String>[],
        providerGenres: metadata?.genres ?? const <String>[],
        providerKeywords: metadata?.keywords ?? const <String>[],
        providerReleaseDate: metadata?.releaseDate,
        providerLastAirDate: metadata?.lastAirDate,
        providerStatus: metadata?.status,
      ));
    } catch (_) {
      // Provider lookup is best effort; never block browsing on missing art.
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl.trim();
    if (url.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) {
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


/// Automatically resolves a missing or failed album cover from the authenticated
/// Spotify/MusicBrainz catalog while retaining local artwork as the first choice.
class AlbumArtworkImage extends StatefulWidget {
  const AlbumArtworkImage({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorPlaceholder,
  });

  final String title;
  final String artist;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  @override
  State<AlbumArtworkImage> createState() => _AlbumArtworkImageState();
}

class _AlbumArtworkImageState extends State<AlbumArtworkImage> {
  String _url = '';
  String _lookupKey = '';
  bool _lookupStarted = false;
  static final Map<String, Future<String?>> _cache = <String, Future<String?>>{};

  String get _currentKey => '${widget.title.trim().toLowerCase()}|'
      '${widget.artist.trim().toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _lookupKey = _currentKey;
    _url = widget.imageUrl?.trim() ?? '';
    AppController.instance.addListener(_onAppControllerChanged);
    if (_url.isEmpty) _resolveIfNeeded();
  }

  void _onAppControllerChanged() {
    _resolveIfNeeded();
  }

  @override
  void dispose() {
    AppController.instance.removeListener(_onAppControllerChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AlbumArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _currentKey;
    if (nextKey != _lookupKey) {
      _lookupKey = nextKey;
      _lookupStarted = false;
      _url = widget.imageUrl?.trim() ?? '';
      if (_url.isEmpty) _resolveIfNeeded();
    } else if (_url.isEmpty && (widget.imageUrl?.trim().isNotEmpty ?? false)) {
      _url = widget.imageUrl!.trim();
    }
  }

  void _resolveIfNeeded() {
    if (_lookupStarted || !CinematicTitleMetadataService.isConfigured) return;
    final title = widget.title.trim();
    if (title.isEmpty) return;
    _lookupStarted = true;
    final key = _currentKey;
    final future = _cache.putIfAbsent(key, () => MediaArtworkAutoResolver.resolveAlbumCover(
          title: title,
          artist: widget.artist,
        ));
    unawaited(_applyResolution(future, key));
  }

  Future<void> _applyResolution(Future<String?> future, String key) async {
    try {
      final url = await future;
      if (!mounted || _lookupKey != key || url == null || url.isEmpty) return;
      setState(() => _url = url);
    } catch (_) {
      // Preserve the placeholder if the catalog lookup fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url.trim();
    if (url.isEmpty) {
      _resolveIfNeeded();
      return widget.placeholder ?? SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF242424),
          child: Center(child: Icon(Icons.album_outlined, color: Colors.white54, size: 28)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, __) => widget.placeholder ?? SizedBox(
        width: widget.width,
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF242424),
          child: Center(child: Icon(Icons.album_outlined, color: Colors.white54, size: 28)),
        ),
      ),
      errorWidget: (_, __, ___) {
        if (!_lookupStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _url = '';
              _lookupStarted = false;
            });
            _resolveIfNeeded();
          });
        }
        return widget.errorPlaceholder ?? widget.placeholder ?? SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ColoredBox(
            color: Color(0xFF242424),
            child: Center(child: Icon(Icons.album_outlined, color: Colors.white54, size: 28)),
          ),
        );
      },
    );
  }
}
