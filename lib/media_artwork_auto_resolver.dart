import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'artwork_selection_store.dart';
import 'energy_saver.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// Resolves missing library artwork through the authenticated backend.
/// TMDB is used for movies/series; Spotify and MusicBrainz are used for albums.
/// Existing user-selected artwork is never replaced.
class MediaArtworkAutoResolver {
  MediaArtworkAutoResolver._();

  static final Map<String, Future<MediaArtworkResult?>> _resultCache =
      <String, Future<MediaArtworkResult?>>{};
  static final Set<String> _warmupAttemptedKeys = <String>{};
  static bool _warmupRunning = false;
  static Timer? _warmupContinuation;
  static String? _warmupContinuationPage;
  static Future<void> _providerLookupTail = Future<void>.value();
  static DateTime? _lastProviderLookupAt;

  static String _token(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  static String _artKey(String type, String id) =>
      'moss_auto_art_${type}_${_token(id)}';


  /// Serializes external metadata queries so a large poster grid cannot fire
  /// dozens of simultaneous network requests. Eco mode deliberately spaces
  /// lookups farther apart; queued work is discarded when its page goes away.
  static Future<T?> _queueProviderLookup<T>(
    Future<T?> Function() operation, {
    required String pageId,
  }) {
    final completer = Completer<T?>();
    Future<void> run() async {
      final energy = EnergySaverController.instance;
      if (!energy.canRunBackgroundWork(pageId: pageId)) {
        energy.recordBackgroundTaskSkipped();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final minimumGap = energy.mode == EnergySaverMode.eco
          ? const Duration(milliseconds: 800)
          : energy.mode == EnergySaverMode.balanced
              ? const Duration(milliseconds: 300)
              : const Duration(milliseconds: 80);
      final last = _lastProviderLookupAt;
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        if (elapsed < minimumGap) {
          await Future<void>.delayed(minimumGap - elapsed);
        }
      }
      if (!energy.canRunBackgroundWork(pageId: pageId)) {
        energy.recordBackgroundTaskSkipped();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      _lastProviderLookupAt = DateTime.now();
      try {
        if (!completer.isCompleted) completer.complete(await operation());
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }

    _providerLookupTail = _providerLookupTail
        .then<void>((_) => run())
        .catchError((Object _) {
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
  }

  static bool isMovieOrShow(MediaItem media) {
    final type = media.type.trim().toLowerCase();
    return media.isSeries ||
        type == 'movie' ||
        type == 'film' ||
        type == 'feature' ||
        type == 'feature film' ||
        type.contains('movie') ||
        type.contains('film') ||
        type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show' ||
        type == 'show' ||
        type.contains('show') ||
        type == 'television' ||
        type == 'episode' ||
        type == 'series' ||
        type.contains('series');
  }

  static bool isAlbum(MediaItem media) {
    final type = media.type.trim().toLowerCase();
    return type.contains('album') ||
        type == 'soundtrack' ||
        type == 'musicrelease' ||
        type == 'music release';
  }

  static String _normalize(String value) => value.toLowerCase().trim().replaceAll(
        RegExp(r'[\s\-_.,:;!?()\[\]{}\\/]+'),
        '',
      );

  static String _cacheKey(MediaItem media) {
    final type = media.isSeries ? 'tv' : media.type.toLowerCase().trim();
    return '${media.id}|$type|${_normalize(media.title)}|'
        '${media.releaseYear ?? media.seriesStartYear ?? ''}|'
        '${_normalize(media.music.join(','))}';
  }

  /// Resolves one item once per process and caches negative matches too.
  static Future<MediaArtworkResult?> resolveMedia(MediaItem media, {String? pageId}) {
    if (!CinematicTitleMetadataService.isConfigured ||
        (!isMovieOrShow(media) && !isAlbum(media))) {
      return Future<MediaArtworkResult?>.value(null);
    }
    final key = _cacheKey(media);
    final energy = EnergySaverController.instance;
    if (!energy.canRunBackgroundWork(pageId: pageId ?? energy.activePage)) {
      energy.recordBackgroundTaskSkipped();
      return Future<MediaArtworkResult?>.value(null);
    }
    final cacheHit = energy.cacheArtwork && _resultCache.containsKey(key);
    energy.recordArtworkLookup(cacheHit: cacheHit);
    Future<MediaArtworkResult?> lookup() async {
      try {
        if (isAlbum(media)) {
          final artist = media.music.map((value) => value.trim()).firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => '',
              );
          final cover = await resolveAlbumCover(
            title: media.title,
            artist: artist,
            year: media.releaseYear,
          );
          return cover == null ? null : MediaArtworkResult(posterUrl: cover);
        }

        final metadata = await CinematicTitleMetadataService.lookupTitle(
          title: media.title,
          isTv: media.isSeries || _isTvType(media.type),
          year: media.releaseYear ?? media.seriesStartYear,
        );
        if (metadata == null) return null;
        return MediaArtworkResult(
          posterUrl: metadata.posterUrl,
          backdropPath: metadata.backdropPath,
          titleMetadata: metadata,
        );
      } catch (_) {
        return null;
      }
    }
    Future<MediaArtworkResult?> scheduledLookup() {
      // resolveAlbumCover runs through the same queue itself. Wrapping it a
      // second time here would make the serialized queue wait on itself.
      if (isAlbum(media)) return lookup();
      return _queueProviderLookup<MediaArtworkResult>(
        lookup,
        pageId: pageId ?? energy.activePage,
      );
    }
    if (!energy.cacheArtwork) return scheduledLookup();
    final cached = _resultCache[key];
    if (cached != null) return cached;

    final queryPage = pageId ?? energy.activePage;
    final future = scheduledLookup();
    _resultCache[key] = future;
    // If navigation/backgrounding cancelled a queued lookup, discard that
    // temporary null so the next visit can retry. Real no-match results remain
    // cached for the current session and don't trigger request loops.
    unawaited(future.then((result) {
      if (result == null &&
          !energy.canRunBackgroundWork(pageId: queryPage) &&
          identical(_resultCache[key], future)) {
        _resultCache.remove(key);
      }
    }));
    return future;
  }

  static bool _isTvType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'tvshow' ||
        type == 'tv_show' ||
        type == 'tv show' ||
        type == 'show' ||
        type.contains('show') ||
        type == 'television' ||
        type == 'episode' ||
        type == 'series' ||
        type.contains('series');
  }

  /// Queue artwork resolution for the page being entered. Lookup work is
  /// serialized and continued in small batches while that page remains active.
  /// Images already supplied by the user/catalog are never replaced.
  static Future<void> warmForPage(String pageId) async {
    final energy = EnergySaverController.instance;
    if (!CinematicTitleMetadataService.isConfigured ||
        !energy.canRunBackgroundWork(pageId: pageId)) {
      energy.recordBackgroundTaskSkipped();
      _warmupContinuation?.cancel();
      _warmupContinuation = null;
      return;
    }

    final page = pageId.trim().toLowerCase();
    if (page == 'player' || page == 'details' || page == 'power-performance' || page == 'settings' ||
        page == 'profiles' || page == 'server-selection' || page == 'boot') {
      return;
    }

    final source = AppController.instance.library;
    Iterable<MediaItem> matching = source;
    if (page == 'movies') {
      matching = source.where((media) => isMovieOrShow(media) && !_isTvType(media.type) && !media.isSeries);
    } else if (page == 'series' || page == 'shows') {
      matching = source.where((media) => isMovieOrShow(media) && (_isTvType(media.type) || media.isSeries));
    } else if (page == 'music') {
      matching = source.where(isAlbum);
    } else if (page != 'home' && page != 'details' && page != 'collections' && page != 'search') {
      return;
    }

    final candidates = matching.where((media) {
      if (!isMovieOrShow(media) && !isAlbum(media)) return false;
      final key = _cacheKey(media);
      if (_warmupAttemptedKeys.contains(key)) return false;
      // Avoid remote requests for items with complete, provider-neutral art.
      final posterPresent = media.imageUrl?.trim().isNotEmpty == true;
      if (isAlbum(media)) return !posterPresent;
      return true; // A backdrop may still be missing even when a poster exists.
    }).toList(growable: false);

    if (candidates.isEmpty) {
      _warmupContinuation?.cancel();
      _warmupContinuation = null;
      _warmupContinuationPage = null;
      return;
    }

    final limit = energy.lowPowerArtworkLoading
        ? (energy.mode == EnergySaverMode.eco ? 3 : 6)
        : (energy.mode == EnergySaverMode.cinema ? 18 : 10);
    final batch = candidates.take(limit).toList(growable: false);
    await warmLibrary(items: batch, pageId: page, maxItems: limit);

    final remaining = candidates.skip(batch.length).isNotEmpty;
    if (remaining && energy.canRunBackgroundWork(pageId: page)) {
      _scheduleWarmupContinuation(page, energy);
    } else {
      _warmupContinuation?.cancel();
      _warmupContinuation = null;
      _warmupContinuationPage = null;
    }
  }

  static void _scheduleWarmupContinuation(
    String page,
    EnergySaverController energy,
  ) {
    _warmupContinuation?.cancel();
    _warmupContinuationPage = page;
    final delay = energy.mode == EnergySaverMode.eco
        ? const Duration(seconds: 22)
        : energy.mode == EnergySaverMode.balanced
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4);
    _warmupContinuation = Timer(delay, () {
      if (_warmupContinuationPage != page ||
          energy.activePage != page ||
          !energy.canRunBackgroundWork(pageId: page)) {
        return;
      }
      unawaited(warmForPage(page));
    });
  }

  /// Details pages call this for the selected item so its missing art can start
  /// loading immediately even if it isn't in the first batch of a browse page.
  static Future<void> warmSelectedMedia(MediaItem media) async {
    final energy = EnergySaverController.instance;
    if (!energy.canRunBackgroundWork(pageId: energy.activePage)) {
      energy.recordBackgroundTaskSkipped();
      return;
    }
    await warmLibrary(items: <MediaItem>[media], pageId: energy.activePage, maxItems: 1);
  }

  /// Fills a small, serialized batch without blocking the UI. In low-power
  /// modes the gaps between provider requests are longer and background work
  /// is abandoned as soon as its page is no longer active.
  static Future<void> warmLibrary({
    Iterable<MediaItem>? items,
    String? pageId,
    int? maxItems,
  }) async {
    final energy = EnergySaverController.instance;
    final activePage = pageId ?? energy.activePage;
    if (!CinematicTitleMetadataService.isConfigured) return;
    // A page switch can happen while a prior small batch is finishing. Wait
    // without doing work so explicitly selected details artwork is not lost;
    // cancel as soon as its page is no longer active.
    while (_warmupRunning) {
      if (!energy.canRunBackgroundWork(pageId: activePage)) {
        energy.recordBackgroundTaskSkipped();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!energy.canRunBackgroundWork(pageId: activePage)) {
      energy.recordBackgroundTaskSkipped();
      return;
    }
    _warmupRunning = true;
    try {
      final profileId = AppController.instance.currentProfile?.id ?? 'guest';
      final libraryItems = (items ?? AppController.instance.library).toList(growable: false);
      var processed = 0;
      final maxCount = maxItems ?? (energy.lowPowerArtworkLoading ? 6 : 16);
      for (final media in libraryItems) {
        if (processed >= maxCount) break;
        if (!CinematicTitleMetadataService.isConfigured) break;
        if (!energy.canRunBackgroundWork(pageId: activePage)) {
          energy.recordBackgroundTaskSkipped();
          break;
        }
        if (!isMovieOrShow(media) && !isAlbum(media)) continue;
        final currentPoster = media.imageUrl?.trim() ?? '';
        final key = _cacheKey(media);
        if (!_warmupAttemptedKeys.add(key)) continue;
        processed++;

        final customBackdrop = isMovieOrShow(media)
            ? await ArtworkSelectionStore.readBackdropPath(
                profileId: profileId,
                mediaId: media.id,
              )
            : null;
        final autoBackdrop = isMovieOrShow(media)
            ? await readAutoBackdropPath(media.id)
            : null;
        final needsPoster = currentPoster.isEmpty;
        final needsBackdrop = isMovieOrShow(media) &&
            (customBackdrop == null || customBackdrop.isEmpty) &&
            (autoBackdrop == null || autoBackdrop.isEmpty);
        if (!needsPoster && !needsBackdrop) continue;

        final result = await resolveMedia(media, pageId: activePage);
        if (result == null) {
          // If the request was abandoned because the viewer navigated away,
          // allow the item to be attempted again on the next visit.
          if (!energy.canRunBackgroundWork(pageId: activePage)) {
            _warmupAttemptedKeys.remove(key);
            break;
          }
          continue;
        }
        await rememberResolvedArtwork(
          media,
          result,
          profileId: profileId,
          persistMissingPoster: needsPoster,
        );

        final gap = energy.mode == EnergySaverMode.eco
            ? const Duration(milliseconds: 650)
            : energy.mode == EnergySaverMode.balanced
                ? const Duration(milliseconds: 240)
                : const Duration(milliseconds: 100);
        await Future<void>.delayed(gap);
      }
    } finally {
      _warmupRunning = false;
    }
  }


  /// Saves automatic artwork without overriding profile-specific selections.
  static Future<void> rememberResolvedArtwork(
    MediaItem media,
    MediaArtworkResult result, {
    String? profileId,
    bool persistMissingPoster = true,
  }) async {
    final activeProfileId = profileId ??
        AppController.instance.currentProfile?.id ?? 'guest';
    final posterUrl = result.posterUrl?.trim() ?? '';
    if (posterUrl.startsWith('http')) {
      if (persistMissingPoster && (media.imageUrl?.trim().isNotEmpty != true)) {
        await AppController.instance.mergeProviderTitleCredits(
          mediaId: media.id,
          posterUrl: posterUrl,
          actors: result.titleMetadata?.cast ?? const <String>[],
          characters: result.titleMetadata?.characters ?? const <String>[],
          directors: result.titleMetadata?.directors ?? const <String>[],
          writers: result.titleMetadata?.writers ?? const <String>[],
          music: result.titleMetadata?.music ?? const <String>[],
          providerGenres: result.titleMetadata?.genres ?? const <String>[],
          providerKeywords: result.titleMetadata?.keywords ?? const <String>[],
          providerReleaseDate: result.titleMetadata?.releaseDate,
          providerLastAirDate: result.titleMetadata?.lastAirDate,
          providerStatus: result.titleMetadata?.status,
        );
      }
      // Keep a separate fallback URL so a broken/stale provider image can be
      // replaced at render time without overwriting existing imported artwork.
      await _writeAutoPosterUrl(media.id, posterUrl);
    }
    final backdropPath = result.backdropPath?.trim() ?? '';
    if (isMovieOrShow(media) && backdropPath.isNotEmpty) {
      final selected = await ArtworkSelectionStore.readBackdropPath(
        profileId: activeProfileId,
        mediaId: media.id,
      );
      if (selected == null || selected.isEmpty) {
        await _writeAutoBackdropPathIfAbsent(media.id, backdropPath);
      }
    }
  }

  /// Resolves an exact TMDB person portrait for actor/actress credits.
  /// Results are persisted by normalized name so a page visit does not repeat
  /// the same network lookup after an app or server restart.
  static final Map<String, Future<String?>> _personPortraitCache =
      <String, Future<String?>>{};

  static Future<String?> resolvePersonPortrait(
    String personName, {
    String? pageId,
  }) async {
    final cleanedName = personName.trim();
    if (cleanedName.isEmpty || !AppController.instance.isBackendAuthenticated) {
      return null;
    }
    final normalized = _normalize(cleanedName);
    if (normalized.isEmpty) return null;
    final cacheKey = 'person|$normalized';
    final inMemory = _personPortraitCache[cacheKey];
    if (inMemory != null) return inMemory;

    Future<String?> lookup() async {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString(_artKey('person', normalized))?.trim();
      if (persisted != null && persisted.startsWith('https://')) return persisted;
      final energy = EnergySaverController.instance;
      final resolvedPage = pageId ?? energy.activePage;
      if (!energy.canRunBackgroundWork(pageId: resolvedPage)) {
        energy.recordBackgroundTaskSkipped();
        return null;
      }
      final payload = await AppController.instance.backendApi.getTmdbMetadata(
        '/search/person',
        <String, String>{
          'query': cleanedName,
          'include_adult': 'false',
          'language': 'en-US',
          'page': '1',
        },
      );
      final rawResults = payload['results'];
      if (rawResults is! List) return null;
      final wanted = _normalize(cleanedName);
      Map<String, dynamic>? selected;
      for (final raw in rawResults.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final name = row['name']?.toString().trim() ?? '';
        final profilePath = row['profile_path']?.toString().trim() ?? '';
        if (name.isEmpty || profilePath.isEmpty || !profilePath.startsWith('/')) continue;
        if (_normalize(name) == wanted) {
          selected = row;
          break;
        }
      }
      if (selected == null) return null;
      final profilePath = selected['profile_path']?.toString() ?? '';
      final url = 'https://image.tmdb.org/t/p/w500$profilePath';
      await prefs.setString(_artKey('person', normalized), url);
      return url;
    }

    final activePage = pageId ?? EnergySaverController.instance.activePage;
    final future = _queueProviderLookup<String>(lookup, pageId: activePage);
    _personPortraitCache[cacheKey] = future;
    try {
      final result = await future;
      if (result == null) _personPortraitCache.remove(cacheKey);
      return result;
    } catch (_) {
      _personPortraitCache.remove(cacheKey);
      return null;
    }
  }

  static Future<String?> readAutoPosterUrl(String mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_artKey('poster', mediaId))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> _writeAutoPosterUrl(String mediaId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_artKey('poster', mediaId)) ?? '').trim().isEmpty) {
      await prefs.setString(_artKey('poster', mediaId), url);
    }
  }

  static Future<String?> readAutoBackdropPath(String mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_artKey('backdrop', mediaId))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> _writeAutoBackdropPathIfAbsent(
    String mediaId,
    String path,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_artKey('backdrop', mediaId)) ?? '').trim().isEmpty) {
      await prefs.setString(_artKey('backdrop', mediaId), path);
    }
  }

  /// Exact-title album cover lookup with artist/year ranking. Existing imported
  /// track artwork remains the primary source; this fills gaps only.
  static Future<String?> resolveAlbumCover({
    required String title,
    required String artist,
    int? year,
  }) async {
    if (!CinematicTitleMetadataService.isConfigured || title.trim().isEmpty) {
      return null;
    }
    final key = 'album|${_normalize(title)}|${_normalize(artist)}|${year ?? ''}';
    final activePage = EnergySaverController.instance.activePage;
    Future<MediaArtworkResult?>? future = _resultCache[key];
    if (future == null) {
      future = _queueProviderLookup<MediaArtworkResult>(() async {
        try {
          final preferences = await SharedPreferences.getInstance();
          final persisted = preferences.getString(_artKey('album', key))?.trim();
          if (persisted != null && persisted.isNotEmpty) {
            return MediaArtworkResult(posterUrl: persisted);
          }
          final result = await _lookupAlbumCover(
            title: title,
            artist: artist,
            year: year,
          );
          final poster = result?.posterUrl?.trim() ?? '';
          if (poster.startsWith('https://') || poster.startsWith('http://')) {
            await preferences.setString(_artKey('album', key), poster);
          }
          return result;
        } catch (_) {
          return null;
        }
      }, pageId: activePage);
      _resultCache[key] = future;
      final scheduled = future;
      unawaited(scheduled.then((result) {
        if (result == null &&
            !EnergySaverController.instance.canRunBackgroundWork(pageId: activePage) &&
            identical(_resultCache[key], scheduled)) {
          _resultCache.remove(key);
        }
      }));
    }
    return (await future)?.posterUrl;
  }

  static Future<MediaArtworkResult?> _lookupAlbumCover({
    required String title,
    required String artist,
    int? year,
  }) async {
    try {
      final payload = await AppController.instance.backendApi.searchMusicCatalog(
        title.trim(),
        type: 'album',
        limit: 10,
      );
      final wantedTitle = _normalize(title);
      final wantedArtist = _normalize(artist);
      final spotify = payload['spotify'] is Map
          ? Map<String, dynamic>.from(payload['spotify'] as Map)
          : <String, dynamic>{};
      final albums = spotify['albums'] is List
          ? (spotify['albums'] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where((row) => _normalize(row['title']?.toString() ?? '') == wantedTitle)
              .toList()
          : <Map<String, dynamic>>[];
      albums.sort((a, b) {
        int score(Map<String, dynamic> row) {
          final candidateArtist = _normalize(row['artist']?.toString() ?? '');
          var points = wantedArtist.isNotEmpty && candidateArtist.contains(wantedArtist) ? 0 : 1;
          if (year != null) {
            final date = row['releaseDate']?.toString() ?? '';
            points += date.startsWith('$year') ? 0 : 2;
          }
          return points;
        }
        return score(a).compareTo(score(b));
      });
      for (final row in albums) {
        final direct = row['imageUrl']?.toString().trim() ?? '';
        if (direct.startsWith('https://') || direct.startsWith('http://')) {
          return MediaArtworkResult(posterUrl: direct);
        }
        final images = row['images'];
        if (images is List) {
          for (final raw in images.whereType<Map>()) {
            final url = raw['url']?.toString().trim() ?? '';
            if (url.startsWith('https://') || url.startsWith('http://')) {
              return MediaArtworkResult(posterUrl: url);
            }
          }
        }
      }

      final musicBrainz = payload['musicBrainz'] is Map
          ? Map<String, dynamic>.from(payload['musicBrainz'] as Map)
          : <String, dynamic>{};
      final groups = musicBrainz['releaseGroups'] is List
          ? (musicBrainz['releaseGroups'] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where((row) => _normalize(row['title']?.toString() ?? '') == wantedTitle)
              .toList()
          : <Map<String, dynamic>>[];
      groups.sort((a, b) {
        final aArtist = _normalize(a['artist']?.toString() ?? '');
        final bArtist = _normalize(b['artist']?.toString() ?? '');
        final aScore = wantedArtist.isNotEmpty && aArtist.contains(wantedArtist) ? 0 : 1;
        final bScore = wantedArtist.isNotEmpty && bArtist.contains(wantedArtist) ? 0 : 1;
        return aScore.compareTo(bScore);
      });
      for (final group in groups) {
        final cover = group['coverArtUrl']?.toString().trim() ?? '';
        if (cover.startsWith('https://') || cover.startsWith('http://')) {
          return MediaArtworkResult(posterUrl: cover);
        }
      }
    } catch (_) {
      // Missing album artwork must never block music browsing.
    }
    return null;
  }
}

class MediaArtworkResult {
  const MediaArtworkResult({this.posterUrl, this.backdropPath, this.titleMetadata});

  final String? posterUrl;
  /// TMDB backdrop file path, persisted separately from a user's chosen art.
  final String? backdropPath;
  final CinematicTitleMetadata? titleMetadata;
}
