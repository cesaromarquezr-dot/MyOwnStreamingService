import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'artwork_selection_store.dart';
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

  static String _token(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  static String _artKey(String type, String id) =>
      'moss_auto_art_${type}_${_token(id)}';

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
  static Future<MediaArtworkResult?> resolveMedia(MediaItem media) {
    if (!CinematicTitleMetadataService.isConfigured ||
        (!isMovieOrShow(media) && !isAlbum(media))) {
      return Future<MediaArtworkResult?>.value(null);
    }
    final key = _cacheKey(media);
    return _resultCache.putIfAbsent(key, () async {
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
    });
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

  /// Fills missing artwork for the library without blocking the UI.
  /// Lookups are deliberately serialized to avoid flooding the metadata backend.
  static Future<void> warmLibrary({Iterable<MediaItem>? items}) async {
    if (!CinematicTitleMetadataService.isConfigured || _warmupRunning) return;
    _warmupRunning = true;
    try {
      final profileId = AppController.instance.currentProfile?.id ?? 'guest';
      final libraryItems = (items ?? AppController.instance.library).toList(growable: false);
      for (final media in libraryItems) {
        if (!CinematicTitleMetadataService.isConfigured) break;
        if (!isMovieOrShow(media) && !isAlbum(media)) continue;
        final currentPoster = media.imageUrl?.trim() ?? '';
        final key = _cacheKey(media);
        if (!_warmupAttemptedKeys.add(key)) continue;

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

        final result = await resolveMedia(media);
        if (result == null) continue;
        await rememberResolvedArtwork(
          media,
          result,
          profileId: profileId,
          persistMissingPoster: needsPoster,
        );
        // Small pause between titles; each title can result in a search and a
        // detail request at the provider, so avoid a burst for large libraries.
        await Future<void>.delayed(const Duration(milliseconds: 90));
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
    final future = _resultCache.putIfAbsent(key, () async {
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
        return _lookupAlbumCover(title: title, artist: artist, year: year);
      }
    });
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
