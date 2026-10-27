// FILE: `Backend/routes/music_catalog_routes.dart`.
// Purpose: Authenticated API endpoints for remote music metadata and artwork.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import '../middleware/authentication.dart';
import '../services/music_catalog_service.dart';

class MusicCatalogRoutes {
  MusicCatalogRoutes({
    required this.authentication,
    required this.service,
  });

  final AuthenticationMiddleware authentication;
  final MusicCatalogService service;

  static const String _prefix = '/api/v1/music-catalog';

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method != 'GET' && request.method != 'POST') {
      await _json(request, HttpStatus.methodNotAllowed, <String, dynamic>{
        'success': false,
        'error': 'Method not allowed.',
      });
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request, HttpStatus.unauthorized, <String, dynamic>{
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }
    // Authentication is required for access; metadata results are not account-specific.
    final _ = account;

    try {
      final path = request.uri.path;
      if (path == '$_prefix/status') {
        await _json(request, HttpStatus.ok, <String, dynamic>{
          'success': true,
          'providers': service.providerStatus(),
        });
        return;
      }

      if (path == '$_prefix/search') {
        final query = request.uri.queryParameters['q']?.trim() ?? '';
        if (query.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A search query is required.',
          });
          return;
        }
        if (query.length > 120 || query.contains('\u0000')) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'Search query must be between 1 and 120 characters.',
          });
          return;
        }
        final type = request.uri.queryParameters['type'] ?? 'all';
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '10') ?? 10;
        final result = await service.search(query: query, type: type, limit: limit);
        await _json(request, HttpStatus.ok, result);
        return;
      }

      if (path == '$_prefix/artist-related') {
        final artistName = request.uri.queryParameters['name']?.trim() ?? '';
        if (artistName.isEmpty || artistName.length > 120 || artistName.contains('\u0000')) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'An artist name between 1 and 120 characters is required.',
          });
          return;
        }
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '12') ?? 12;
        await _json(request, HttpStatus.ok, await service.relatedArtists(artistName: artistName, limit: limit));
        return;
      }

      if (path == '$_prefix/artist-popular') {
        final artistName = request.uri.queryParameters['name']?.trim() ?? '';
        if (artistName.isEmpty || artistName.length > 120 || artistName.contains('\u0000')) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'An artist name between 1 and 120 characters is required.',
          });
          return;
        }
        await _json(request, HttpStatus.ok, await service.popularArtistTracks(artistName: artistName));
        return;
      }

      if (path == '$_prefix/lyrics-search') {
        final query = request.uri.queryParameters['q']?.trim() ?? '';
        if (query.length < 3 || query.length > 180 || query.contains('\u0000')) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A lyric phrase between 3 and 180 characters is required.',
          });
          return;
        }
        await _json(request, HttpStatus.ok, await service.searchByLyrics(query: query));
        return;
      }

      if (path == '$_prefix/recognize') {
        if (request.method != 'POST') {
          await _json(request, HttpStatus.methodNotAllowed, <String, dynamic>{'success': false, 'error': 'Use POST to identify a song.'});
          return;
        }
        final contentLength = request.contentLength;
        if (contentLength > 7 * 1024 * 1024) {
          await _json(request, HttpStatus.requestEntityTooLarge, <String, dynamic>{'success': false, 'error': 'Audio sample payload is too large.'});
          return;
        }
        final bodyBuilder = BytesBuilder(copy: false);
        var receivedBytes = 0;
        await for (final chunk in request) {
          receivedBytes += chunk.length;
          if (receivedBytes > 7 * 1024 * 1024) {
            await _json(request, HttpStatus.requestEntityTooLarge, <String, dynamic>{'success': false, 'error': 'Audio sample payload is too large.'});
            return;
          }
          bodyBuilder.add(chunk);
        }
        final decodedBody = jsonDecode(utf8.decode(bodyBuilder.takeBytes()));
        if (decodedBody is! Map) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{'success': false, 'error': 'A JSON audio payload is required.'});
          return;
        }
        final encodedAudio = decodedBody['audioBase64']?.toString() ?? '';
        final mimeType = decodedBody['mimeType']?.toString() ?? 'audio/mp4';
        if (encodedAudio.isEmpty || encodedAudio.length > 7 * 1024 * 1024) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{'success': false, 'error': 'A valid audio sample is required.'});
          return;
        }
        final audio = base64Decode(encodedAudio);
        if (audio.isEmpty || audio.length > 5 * 1024 * 1024) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{'success': false, 'error': 'Audio sample must be no larger than 5 MB.'});
          return;
        }
        await _json(request, HttpStatus.ok, await service.recognizeSong(audioBytes: audio, mimeType: mimeType));
        return;
      }

      if (path == '$_prefix/videos') {
        final query = request.uri.queryParameters['q']?.trim() ?? '';
        if (query.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A music-video search query is required.',
          });
          return;
        }
        if (query.length > 180 || query.contains('\u0000')) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'Music-video search query must be between 1 and 180 characters.',
          });
          return;
        }
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '6') ?? 6;
        final result = await service.searchMusicVideos(query: query, limit: limit);
        await _json(request, HttpStatus.ok, result);
        return;
      }

      if (path == '$_prefix/featured-albums') {
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '10') ?? 10;
        final offset = int.tryParse(request.uri.queryParameters['offset'] ?? '0') ?? 0;
        await _json(request, HttpStatus.ok, await service.featuredAlbums(
          limit: limit,
          offset: offset,
        ));
        return;
      }

      if (path == '$_prefix/artist') {
        final spotifyId = request.uri.queryParameters['spotifyId']?.trim() ?? '';
        if (spotifyId.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A Spotify artist ID is required.',
          });
          return;
        }
        await _json(request, HttpStatus.ok, await service.artistDetails(spotifyId: spotifyId));
        return;
      }

      if (path == '$_prefix/artist-albums') {
        final spotifyId = request.uri.queryParameters['spotifyId']?.trim() ?? '';
        if (spotifyId.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A Spotify artist ID is required.',
          });
          return;
        }
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '10') ?? 10;
        final offset = int.tryParse(request.uri.queryParameters['offset'] ?? '0') ?? 0;
        await _json(request, HttpStatus.ok, await service.artistAlbums(
          spotifyId: spotifyId,
          limit: limit,
          offset: offset,
        ));
        return;
      }

      if (path == '$_prefix/album') {
        final spotifyId = request.uri.queryParameters['spotifyId']?.trim() ?? '';
        if (spotifyId.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A Spotify album ID is required.',
          });
          return;
        }
        await _json(request, HttpStatus.ok, await service.albumDetails(spotifyId: spotifyId));
        return;
      }

      if (path == '$_prefix/discography') {
        final mbid = request.uri.queryParameters['mbid']?.trim() ?? '';
        if (mbid.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A MusicBrainz artist MBID is required.',
          });
          return;
        }
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '100') ?? 100;
        final items = await service.discography(artistMbid: mbid, limit: limit);
        await _json(request, HttpStatus.ok, <String, dynamic>{
          'success': true,
          'mbid': mbid,
          'items': items,
          'count': items.length,
        });
        return;
      }

      if (path == '$_prefix/cover-art') {
        final mbid = request.uri.queryParameters['mbid']?.trim() ?? '';
        final entity = request.uri.queryParameters['entity'] ?? 'release-group';
        if (mbid.isEmpty) {
          await _json(request, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A MusicBrainz MBID is required.',
          });
          return;
        }
        final result = await service.coverArt(mbid: mbid, entity: entity);
        await _json(request, HttpStatus.ok, result);
        return;
      }

      await _json(request, HttpStatus.notFound, <String, dynamic>{
        'success': false,
        'error': 'Music catalog route not found.',
      });
    } on FormatException catch (error) {
      await _json(request, HttpStatus.badRequest, <String, dynamic>{
        'success': false,
        'error': error.message,
      });
    } on MusicCatalogUpstreamException catch (error, stackTrace) {
      developer.log(
        'Music catalog upstream provider failed.',
        name: 'MusicCatalogRoutes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, HttpStatus.badGateway, <String, dynamic>{
        'success': false,
        'error': 'A music metadata provider is temporarily unavailable.',
      });
    } catch (error, stackTrace) {
      developer.log(
        'Music catalog request failed.',
        name: 'MusicCatalogRoutes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request, HttpStatus.internalServerError, <String, dynamic>{
        'success': false,
        'error': 'Unable to load the music catalog right now.',
      });
    }
  }

  Future<void> _json(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> payload,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Cache-Control', 'private, max-age=60');
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}
