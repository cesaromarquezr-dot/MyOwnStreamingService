// FILE: `Backend/services/music_catalog_service.dart`.
// Purpose: Server-side catalog discovery for music artists, albums, recordings,
// discographies, and artwork. Spotify credentials never leave this backend.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MusicCatalogUpstreamException implements Exception {
  final int statusCode;
  final String message;

  const MusicCatalogUpstreamException(this.statusCode, this.message);

  @override
  String toString() => 'MusicCatalogUpstreamException($statusCode): $message';
}

class MusicCatalogService {
  MusicCatalogService({
    required this.spotifyClientId,
    required this.spotifyClientSecret,
    required this.youtubeApiKey,
    required this.musixmatchApiKey,
    required this.auddApiToken,
    required this.userAgent,
    required this.tmdbApiKey,
    required this.tmdbApiToken,
  }) : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
    _client.idleTimeout = const Duration(seconds: 20);
  }

  final String spotifyClientId;
  final String spotifyClientSecret;
  final String youtubeApiKey;
  final String musixmatchApiKey;
  final String auddApiToken;
  final String userAgent;
  final String tmdbApiKey;
  final String tmdbApiToken;
  final HttpClient _client;

  String? _spotifyToken;
  DateTime? _spotifyTokenExpiresAt;

  // MusicBrainz asks clients to stay at or below one request per second.
  // This queue serializes calls across concurrent app users on this backend.
  static Future<void> _musicBrainzQueue = Future<void>.value();
  static DateTime _lastMusicBrainzRequestAt =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  bool get spotifyConfigured =>
      spotifyClientId.trim().isNotEmpty &&
      spotifyClientSecret.trim().isNotEmpty;

  bool get tmdbConfigured =>
      tmdbApiToken.trim().isNotEmpty || tmdbApiKey.trim().isNotEmpty;

  bool get youtubeVideosConfigured => youtubeApiKey.trim().isNotEmpty;
  bool get lyricsSearchConfigured => musixmatchApiKey.trim().isNotEmpty;
  bool get songRecognitionConfigured => auddApiToken.trim().isNotEmpty;

  Map<String, dynamic> providerStatus() => <String, dynamic>{
        'spotify': <String, dynamic>{
          'configured': spotifyConfigured,
          'purpose': 'Artist, album, and track metadata search',
        },
        'musicBrainz': <String, dynamic>{
          'configured': true,
          'purpose': 'Artist identities, recordings, releases, and discographies',
          'apiKeyRequired': false,
        },
        'tmdb': <String, dynamic>{
          'configured': tmdbConfigured,
          'purpose': 'Supplementary biographies and person portraits for matching artists',
        },
        'coverArtArchive': <String, dynamic>{
          'configured': true,
          'purpose': 'Community-sourced album/release artwork',
          'apiKeyRequired': false,
        },
        'youtubeMusicVideos': <String, dynamic>{
          'configured': youtubeVideosConfigured,
          'purpose': 'Search embeddable music-video matches for a song and artist',
          'apiKeyRequired': true,
        },
        'lyricsSearch': <String, dynamic>{
          'configured': lyricsSearchConfigured,
          'purpose': 'Search licensed track metadata by a remembered lyric phrase',
          'provider': 'Musixmatch',
          'apiKeyRequired': true,
        },
        'songRecognition': <String, dynamic>{
          'configured': songRecognitionConfigured,
          'purpose': 'Identify a song from a short user-recorded audio sample',
          'provider': 'AudD',
          'apiKeyRequired': true,
        },
      };

  Future<Map<String, dynamic>> search({
    required String query,
    String type = 'all',
    int limit = 10,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw const FormatException('A search query is required.');
    }
    if (cleanQuery.length > 120) {
      throw const FormatException('Search query must be 120 characters or fewer.');
    }

    final cleanType = _normalizeType(type);
    final boundedLimit = limit.clamp(1, 10).toInt();
    final warnings = <String>[];
    final spotify = <String, dynamic>{
      'artists': <Map<String, dynamic>>[],
      'albums': <Map<String, dynamic>>[],
      'tracks': <Map<String, dynamic>>[],
    };
    final musicBrainz = <String, dynamic>{
      'artists': <Map<String, dynamic>>[],
      'releaseGroups': <Map<String, dynamic>>[],
      'recordings': <Map<String, dynamic>>[],
    };

    final tasks = <Future<void>>[];
    if (spotifyConfigured) {
      tasks.add(() async {
        try {
          final response = await _searchSpotify(
            cleanQuery,
            type: cleanType,
            limit: boundedLimit,
          );
          spotify.addAll(response);
        } catch (_) {
          warnings.add('Spotify search is temporarily unavailable. Check the server credentials and Spotify developer-app access.');
        }
      }());
    } else {
      warnings.add('Spotify is not configured yet. Add SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET to Backend/.env.');
    }

    if (cleanType == 'all' || cleanType == 'artist') {
      tasks.add(() async {
        try {
          musicBrainz['artists'] = await _searchMusicBrainzEntity(
            entity: 'artist',
            queryField: 'artist',
            query: cleanQuery,
            limit: boundedLimit,
            resultKey: 'artists',
          );
        } catch (_) {
          warnings.add('MusicBrainz artist search is temporarily unavailable.');
        }
      }());
    }

    if (cleanType == 'all' || cleanType == 'album') {
      tasks.add(() async {
        try {
          musicBrainz['releaseGroups'] = await _searchMusicBrainzEntity(
            entity: 'release-group',
            queryField: 'releasegroup',
            query: cleanQuery,
            limit: boundedLimit,
            resultKey: 'release-groups',
          );
        } catch (_) {
          warnings.add('MusicBrainz album search is temporarily unavailable.');
        }
      }());
    }

    if (cleanType == 'all' || cleanType == 'track' || cleanType == 'recording') {
      tasks.add(() async {
        try {
          musicBrainz['recordings'] = await _searchMusicBrainzEntity(
            entity: 'recording',
            queryField: 'recording',
            query: cleanQuery,
            limit: boundedLimit,
            resultKey: 'recordings',
          );
        } catch (_) {
          warnings.add('MusicBrainz recording search is temporarily unavailable.');
        }
      }());
    }

    await Future.wait(tasks);
    return <String, dynamic>{
      'success': true,
      'query': cleanQuery,
      'type': cleanType,
      'providers': providerStatus(),
      'spotify': spotify,
      'musicBrainz': musicBrainz,
      'warnings': warnings,
    };
  }

  /// Searches YouTube for embeddable music-video matches for a song.
  /// Spotify remains the source for track metadata; YouTube is the video source.
  /// When no YouTube key is configured, the UI can still open the query on YouTube.
  Future<Map<String, dynamic>> searchMusicVideos({
    required String query,
    int limit = 6,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw const FormatException('A music-video search query is required.');
    }
    if (cleanQuery.length > 180 || cleanQuery.contains('\u0000')) {
      throw const FormatException('Music-video search query must be between 1 and 180 characters.');
    }

    final searchUrl = Uri.https('www.youtube.com', '/results', <String, String>{
      'search_query': cleanQuery,
    }).toString();
    if (!youtubeVideosConfigured) {
      return <String, dynamic>{
        'success': true,
        'configured': false,
        'source': 'YouTube',
        'query': cleanQuery,
        'items': <Map<String, dynamic>>[],
        'count': 0,
        'searchUrl': searchUrl,
        'message': 'Add YOUTUBE_API_KEY to Backend/.env to show video results inside MyOwnStreamingService. You can still search YouTube directly.',
      };
    }

    final boundedLimit = limit.clamp(1, 10).toInt();
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', <String, String>{
      'part': 'snippet',
      'type': 'video',
      'videoEmbeddable': 'true',
      'safeSearch': 'moderate',
      'maxResults': '$boundedLimit',
      'q': cleanQuery,
      'key': youtubeApiKey.trim(),
    });
    final payload = await _getJson(uri);
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final idPayload = item['id'] is Map
                ? Map<String, dynamic>.from(item['id'] as Map)
                : <String, dynamic>{};
            final snippet = item['snippet'] is Map
                ? Map<String, dynamic>.from(item['snippet'] as Map)
                : <String, dynamic>{};
            final videoId = idPayload['videoId']?.toString() ?? '';
            final thumbnails = snippet['thumbnails'] is Map
                ? Map<String, dynamic>.from(snippet['thumbnails'] as Map)
                : <String, dynamic>{};
            String thumbnailFor(String key) {
              final value = thumbnails[key];
              if (value is Map) return _secureImageUrl(value['url']?.toString());
              return '';
            }
            final thumbnail = <String>[
              thumbnailFor('high'),
              thumbnailFor('medium'),
              thumbnailFor('default'),
            ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
            if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) return null;
            return <String, dynamic>{
              'id': videoId,
              'videoId': videoId,
              'title': snippet['title']?.toString() ?? 'Untitled video',
              'description': snippet['description']?.toString() ?? '',
              'channelTitle': snippet['channelTitle']?.toString() ?? '',
              'publishedAt': snippet['publishedAt']?.toString() ?? '',
              'thumbnailUrl': thumbnail,
              'watchUrl': 'https://www.youtube.com/watch?v=$videoId',
              'embedUrl': 'https://www.youtube.com/embed/$videoId',
              'source': 'YouTube',
            };
          }).whereType<Map<String, dynamic>>().toList(growable: false)
        : <Map<String, dynamic>>[];

    return <String, dynamic>{
      'success': true,
      'configured': true,
      'source': 'YouTube',
      'query': cleanQuery,
      'items': items,
      'count': items.length,
      'searchUrl': searchUrl,
      'message': items.isEmpty ? 'YouTube returned no embeddable video matches for this query.' : '',
    };
  }

  /// Detailed artist profile from Spotify. Spotify does not expose a biography
  /// field; when TMDB has an exact matching person entry, its biography is added
  /// as an explicitly attributed supplementary field.
  Future<Map<String, dynamic>> artistDetails({required String spotifyId}) async {
    final id = _validateSpotifyId(spotifyId);
    final item = await _spotifyGet('/v1/artists/$id');
    final name = item['name']?.toString() ?? 'Unknown artist';
    Map<String, dynamic>? tmdbPerson;
    if (tmdbConfigured && name.trim().isNotEmpty) {
      try {
        tmdbPerson = await _findTmdbPersonForArtist(name);
      } catch (_) {
        // Spotify data remains useful if TMDB has no matching profile or is down.
      }
    }
    final images = _spotifyImages(item['images']);
    final followers = item['followers'] is Map
        ? (item['followers'] as Map)['total']
        : null;
    return <String, dynamic>{
      'success': true,
      'source': 'Spotify',
      'id': id,
      'name': name,
      'genres': item['genres'] is List
          ? (item['genres'] as List).map((v) => v.toString()).toList()
          : <String>[],
      'followers': followers,
      'popularity': item['popularity'],
      'imageUrl': images.isNotEmpty ? images.first['url'] : '',
      'images': images,
      'spotifyUrl': _spotifyExternalUrl(item),
      'biography': tmdbPerson?['biography']?.toString() ?? '',
      'biographySource': (tmdbPerson?['biography']?.toString().trim().isNotEmpty ?? false)
          ? 'TMDB'
          : '',
      'tmdbPersonId': tmdbPerson?['id'],
      'tmdbPersonProfileUrl': _tmdbProfileUrl(tmdbPerson?['profile_path']?.toString()),
      'biographyNote': tmdbPerson == null
          ? 'Spotify does not provide artist biographies through the Web API. No exact matching TMDB person biography was found.'
          : '',
      'attribution': 'Artist metadata and images provided by Spotify; open the artist in Spotify for the original source.',
    };
  }

  /// Finds artist candidates using shared Spotify genre tags. Spotify's related-
  /// artists endpoint is unavailable to many Development Mode apps, so this
  /// deliberately labels its result as a genre-based similarity, not a listener graph.
  Future<Map<String, dynamic>> relatedArtists({
    required String artistName,
    int limit = 12,
  }) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) throw const FormatException('An artist name is required.');
    if (!spotifyConfigured) {
      return <String, dynamic>{'success': true, 'configured': false, 'items': <Map<String, dynamic>>[], 'message': 'Spotify is not configured.'};
    }
    final seedSearch = await _searchSpotify(cleanName, type: 'artist', limit: 5);
    final rawArtists = seedSearch['artists'] is List ? (seedSearch['artists'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : <Map<String, dynamic>>[];
    String norm(String value) => value.toLowerCase().trim().replaceAll(RegExp(r'[\s._\-&,/()]+' ), '');
    final targetNorm = norm(cleanName);
    Map<String, dynamic>? seed;
    for (final row in rawArtists) {
      if (norm(row['name']?.toString() ?? '') == targetNorm) { seed = row; break; }
    }
    seed ??= rawArtists.isEmpty ? null : rawArtists.first;
    if (seed == null || (seed['id']?.toString() ?? '').isEmpty) {
      return <String, dynamic>{'success': true, 'configured': true, 'items': <Map<String, dynamic>>[], 'message': 'No exact Spotify artist match was found.'};
    }
    final seedGenres = seed['genres'] is List ? (seed['genres'] as List).map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList() : <String>[];
    if (seedGenres.isEmpty) {
      return <String, dynamic>{'success': true, 'configured': true, 'seedArtist': seed, 'items': <Map<String, dynamic>>[], 'message': 'Spotify has no genre tags for this artist yet.'};
    }
    final candidateRows = <Map<String, dynamic>>[];
    for (final genre in seedGenres.take(4)) {
      try {
        final escapedGenre = genre.replaceAll('"', '');
        final results = await _searchSpotify('genre:"$escapedGenre"', type: 'artist', limit: 10);
        final rows = results['artists'];
        if (rows is List) candidateRows.addAll(rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
      } catch (_) {
        // Keep useful matches from other genre queries if one provider query fails.
      }
    }
    final seedId = seed['id']?.toString() ?? '';
    final byId = <String, Map<String, dynamic>>{};
    for (final candidate in candidateRows) {
      final id = candidate['id']?.toString() ?? '';
      if (id.isEmpty || id == seedId) continue;
      final candidateGenres = candidate['genres'] is List ? (candidate['genres'] as List).map((value) => value.toString()).toList() : <String>[];
      final shared = candidateGenres.where((genre) => seedGenres.any((seedGenre) => seedGenre.toLowerCase() == genre.toLowerCase())).toSet().toList();
      if (shared.isEmpty) continue;
      final existing = byId[id];
      final score = shared.length * 100;
      final previousScore = (existing?['similarityScore'] as num?)?.toInt() ?? -1;
      if (score > previousScore) {
        byId[id] = <String, dynamic>{...candidate, 'similarityScore': score, 'similarityReason': 'Shares ${shared.take(3).join(', ')}'};
      }
    }
    final items = byId.values.toList()
      ..sort((a, b) => ((b['similarityScore'] as num?)?.toInt() ?? 0).compareTo((a['similarityScore'] as num?)?.toInt() ?? 0));
    return <String, dynamic>{
      'success': true,
      'configured': true,
      'seedArtist': seed,
      'seedGenres': seedGenres,
      'items': items.take(limit.clamp(1, 20).toInt()).toList(growable: false),
      'source': 'Spotify artist genre metadata',
      'message': 'Similar-sounding artists are ranked from shared Spotify genre tags. This is not an official Spotify Fans Also Like ranking.',
    };
  }

  /// Returns Spotify Search's best-ranked tracks for an artist. Spotify removed
  /// the old artist top-tracks endpoint for Development Mode; this is catalog
  /// search-ranked data and never claims to be an official chart.
  Future<Map<String, dynamic>> popularArtistTracks({required String artistName, int limit = 10}) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) throw const FormatException('An artist name is required.');
    if (!spotifyConfigured) return <String, dynamic>{'success': true, 'configured': false, 'items': <Map<String, dynamic>>[], 'message': 'Spotify is not configured.'};
    final result = await _searchSpotify('artist:"${cleanName.replaceAll('"', '')}"', type: 'track', limit: limit.clamp(1, 10).toInt());
    final raw = result['tracks'];
    final items = raw is List ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : <Map<String, dynamic>>[];
    return <String, dynamic>{'success': true, 'configured': true, 'source': 'Spotify Search', 'items': items, 'count': items.length, 'message': 'Tracks are ordered by Spotify Search relevance. Spotify no longer returns track popularity in the current Development Mode API responses.'};
  }

  /// Searches licensed track metadata using a remembered phrase. Only song
  /// metadata and a provider link are returned; full copyrighted lyrics are not copied.
  Future<Map<String, dynamic>> searchByLyrics({required String query, int limit = 10}) async {
    final phrase = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (phrase.length < 3) throw const FormatException('Enter at least 3 characters from the lyric.');
    if (phrase.length > 180 || phrase.contains('\u0000')) throw const FormatException('Lyric search must be 3 to 180 characters.');
    if (!lyricsSearchConfigured) {
      return <String, dynamic>{'success': true, 'configured': false, 'provider': 'Musixmatch', 'items': <Map<String, dynamic>>[], 'message': 'Add MUSIXMATCH_API_KEY to Backend/.env to search licensed track metadata by lyric phrase.'};
    }
    final uri = Uri.https('api.musixmatch.com', '/ws/1.1/track.search', <String, String>{
      'apikey': musixmatchApiKey,
      'q_lyrics': phrase,
      'page': '1',
      'page_size': '${limit.clamp(1, 10)}',
      's_track_rating': 'desc',
    });
    final payload = await _getJson(uri);
    final message = payload['message'] is Map ? Map<String, dynamic>.from(payload['message'] as Map) : <String, dynamic>{};
    final status = message['header'] is Map ? Map<String, dynamic>.from(message['header'] as Map) : <String, dynamic>{};
    if ((status['status_code'] as num?)?.toInt() != 200) throw const FormatException('Musixmatch could not complete this lyric search. Check your API access and terms.');
    final body = message['body'] is Map ? Map<String, dynamic>.from(message['body'] as Map) : <String, dynamic>{};
    final raw = body['track_list'];
    final items = raw is List ? raw.whereType<Map>().map((entry) {
      final item = Map<String, dynamic>.from(entry);
      final track = item['track'] is Map ? Map<String, dynamic>.from(item['track'] as Map) : item;
      return <String, dynamic>{
        'id': track['track_id']?.toString() ?? '',
        'title': track['track_name']?.toString() ?? 'Unknown title',
        'artist': track['artist_name']?.toString() ?? 'Unknown artist',
        'album': track['album_name']?.toString() ?? '',
        'rating': track['track_rating'],
        'explicit': (track['explicit'] as num?)?.toInt() == 1,
        'providerUrl': track['track_share_url']?.toString() ?? '',
        'source': 'Musixmatch',
      };
    }).toList(growable: false) : <Map<String, dynamic>>[];
    return <String, dynamic>{'success': true, 'configured': true, 'provider': 'Musixmatch', 'query': phrase, 'items': items, 'count': items.length, 'message': items.isEmpty ? 'No matching songs were found for that lyric phrase.' : 'Matches use licensed provider metadata; full lyric text is not copied into results.'};
  }

  /// Identifies a short microphone sample using AudD. Audio is processed only
  /// for the user-requested identification and is not written to app logs.
  Future<Map<String, dynamic>> recognizeSong({required List<int> audioBytes, required String mimeType}) async {
    if (!songRecognitionConfigured) {
      return <String, dynamic>{'success': false, 'configured': false, 'provider': 'AudD', 'message': 'Add AUDD_API_TOKEN to Backend/.env to enable song recognition.'};
    }
    if (audioBytes.isEmpty || audioBytes.length > 5 * 1024 * 1024) throw const FormatException('Audio sample must be non-empty and no larger than 5 MB.');
    final boundary = 'moss-${DateTime.now().microsecondsSinceEpoch}';
    final request = await _client.postUrl(Uri.https('api.audd.io', '/')).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    void writeField(String name, String value) {
      request.add(utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n$value\r\n'));
    }
    writeField('api_token', auddApiToken);
    writeField('return', 'spotify,apple_music,deezer');
    final safeMime = mimeType.toLowerCase().contains('wav') ? 'audio/wav' : (mimeType.toLowerCase().contains('mpeg') ? 'audio/mpeg' : 'audio/mp4');
    request.add(utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="file"; filename="sample.${safeMime == 'audio/wav' ? 'wav' : (safeMime == 'audio/mpeg' ? 'mp3' : 'm4a')}"\r\nContent-Type: $safeMime\r\n\r\n'));
    request.add(audioBytes);
    request.add(utf8.encode('\r\n--$boundary--\r\n'));
    final response = await request.close().timeout(const Duration(seconds: 25));
    final bodyText = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) throw MusicCatalogUpstreamException(response.statusCode, 'Song recognition provider returned HTTP ${response.statusCode}.');
    final payload = _decodeJsonMap(bodyText);
    if (payload['status']?.toString() != 'success' || payload['result'] is! Map) {
      return <String, dynamic>{'success': true, 'configured': true, 'matched': false, 'provider': 'AudD', 'message': payload['error'] is Map ? ((payload['error'] as Map)['error_message']?.toString() ?? 'No song match was found.') : 'No song match was found in this sample.'};
    }
    final result = Map<String, dynamic>.from(payload['result'] as Map);
    final spotify = result['spotify'] is Map ? Map<String, dynamic>.from(result['spotify'] as Map) : <String, dynamic>{};
    return <String, dynamic>{
      'success': true,
      'configured': true,
      'matched': true,
      'provider': 'AudD',
      'title': result['title']?.toString() ?? '',
      'artist': result['artist']?.toString() ?? '',
      'album': result['album']?.toString() ?? '',
      'releaseDate': result['release_date']?.toString() ?? '',
      'songLink': result['song_link']?.toString() ?? '',
      'spotifyUrl': spotify['external_urls'] is Map ? ((spotify['external_urls'] as Map)['spotify']?.toString() ?? '') : '',
      'message': 'Song match provided by AudD. Confirm the title before adding it to your library.',
    };
  }

  /// Returns recent albums using Spotify Search year filters. The old
  /// /browse/new-releases endpoint was removed from Spotify's Web API access
  /// for Development Mode apps, so this is explicitly a search-based fallback.
  Future<Map<String, dynamic>> featuredAlbums({
    int limit = 10,
    int offset = 0,
  }) async {
    if (!spotifyConfigured) {
      return <String, dynamic>{
        'success': true,
        'source': 'Spotify Search',
        'items': <Map<String, dynamic>>[],
        'total': 0,
        'configured': false,
      };
    }
    final boundedLimit = limit.clamp(1, 10).toInt();
    final boundedOffset = offset.clamp(0, 1000).toInt();
    final nowYear = DateTime.now().year;
    final byId = <String, Map<String, dynamic>>{};
    for (final year in <int>[nowYear, nowYear - 1, nowYear - 2]) {
      try {
        final page = await _searchSpotify('year:$year', type: 'album', limit: 10);
        final raw = page['albums'];
        if (raw is! List) continue;
        for (final row in raw.whereType<Map>()) {
          final album = Map<String, dynamic>.from(row);
          final id = album['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          byId.putIfAbsent(id, () => album);
        }
      } catch (_) {
        // Continue to older years when a provider query is temporarily unavailable.
      }
      if (byId.length >= (boundedOffset + boundedLimit)) break;
    }
    final items = byId.values.toList()
      ..sort((a, b) => (b['releaseDate']?.toString() ?? '')
          .compareTo(a['releaseDate']?.toString() ?? ''));
    final pageItems = items.skip(boundedOffset).take(boundedLimit).toList(growable: false);
    return <String, dynamic>{
      'success': true,
      'configured': true,
      'source': 'Spotify Search (year-filtered catalogue)',
      'items': pageItems,
      'count': pageItems.length,
      'total': items.length,
      'limit': boundedLimit,
      'offset': boundedOffset,
      'message': 'Recent albums are discovered through Spotify Search; this is not an official Spotify New Releases feed.',
    };
  }

  /// Returns Spotify album releases for the artist. Spotify limits this endpoint
  /// to ten items per request, so callers can use offset to page through results.
  Future<Map<String, dynamic>> artistAlbums({
    required String spotifyId,
    int limit = 10,
    int offset = 0,
  }) async {
    final id = _validateSpotifyId(spotifyId);
    final boundedLimit = limit.clamp(1, 10).toInt();
    final boundedOffset = offset.clamp(0, 10000).toInt();
    final payload = await _spotifyGet(
      '/v1/artists/$id/albums',
      query: <String, String>{
        'include_groups': 'album,single,compilation,appears_on',
        'market': 'MX',
        'limit': '$boundedLimit',
        'offset': '$boundedOffset',
      },
    );
    final raw = payload['items'];
    final items = raw is List
        ? raw.whereType<Map>().map((entry) => _spotifyAlbumSummary(
              Map<String, dynamic>.from(entry),
            )).toList()
        : <Map<String, dynamic>>[];
    return <String, dynamic>{
      'success': true,
      'artistId': id,
      'items': items,
      'count': items.length,
      'total': payload['total'] ?? items.length,
      'limit': boundedLimit,
      'offset': boundedOffset,
      'next': payload['next'],
      'source': 'Spotify',
    };
  }

  /// Loads album metadata and the album's track list from Spotify.
  Future<Map<String, dynamic>> albumDetails({required String spotifyId}) async {
    final id = _validateSpotifyId(spotifyId);
    final album = await _spotifyGet(
      '/v1/albums/$id',
      query: const <String, String>{'market': 'MX'},
    );
    final tracks = <Map<String, dynamic>>[];
    String? trackWarning;
    var reportedTrackTotal = 0;
    var offset = 0;
    try {
      // Spotify's track endpoint is paginated. Follow its `next` signal so
      // the UI gets the full listing for ordinary albums rather than only
      // the first page. The page cap protects against malformed provider data.
      for (var page = 0; page < 10; page++) {
        final trackPayload = await _spotifyGet(
          '/v1/albums/$id/tracks',
          query: <String, String>{
            'market': 'MX',
            'limit': '50',
            'offset': '$offset',
          },
        );
        reportedTrackTotal = int.tryParse(
              trackPayload['total']?.toString() ?? '',
            ) ?? reportedTrackTotal;
        final rawTracks = trackPayload['items'];
        if (rawTracks is! List || rawTracks.isEmpty) break;
        tracks.addAll(rawTracks.whereType<Map>().map((raw) =>
            _spotifyTrackSummary(Map<String, dynamic>.from(raw))));
        offset += rawTracks.length;
        final next = trackPayload['next']?.toString() ?? '';
        if (next.isEmpty || (reportedTrackTotal > 0 && tracks.length >= reportedTrackTotal)) {
          break;
        }
      }
      if (reportedTrackTotal > tracks.length && tracks.length >= 500) {
        trackWarning = 'The album has more tracks than this response limit; showing the first ${tracks.length} tracks.';
      }
    } catch (_) {
      // Some Spotify app modes may restrict the track endpoint. Keep any
      // tracks already fetched, otherwise use any embedded track rows available.
      if (tracks.isEmpty) {
        final embedded = album['tracks'];
        final rawTracks = embedded is Map ? embedded['items'] : null;
        if (rawTracks is List) {
          tracks.addAll(rawTracks.whereType<Map>().map((raw) =>
              _spotifyTrackSummary(Map<String, dynamic>.from(raw))));
        }
      }
      trackWarning = tracks.isEmpty
          ? 'Spotify returned album metadata, but its track-list endpoint was unavailable.'
          : 'Some track pages were unavailable; the displayed listing may be incomplete.';
    }

    final images = _spotifyImages(album['images']);
    final albumTitle = album['name']?.toString() ?? 'Untitled album';
    final artistNames = _spotifyArtistNames(album['artists']);
    // Spotify provides album artists, label, copyrights and track listings,
    // but it does not reliably expose composers/producers. Enrich those credits
    // from MusicBrainz when there is an exact album-title match. This is best
    // effort and never invents a credit when the provider has none.
    Map<String, dynamic> musicBrainzCredits = <String, dynamic>{};
    try {
      musicBrainzCredits = await _musicBrainzAlbumCredits(
        albumTitle: albumTitle,
        artistNames: artistNames,
        releaseDate: album['release_date']?.toString() ?? '',
        spotifyTracks: tracks,
      );
    } catch (_) {
      musicBrainzCredits = <String, dynamic>{};
    }
    var imageUrl = images.isNotEmpty ? images.first['url']?.toString() ?? '' : '';
    if (imageUrl.isEmpty && (musicBrainzCredits['releaseGroupMbid']?.toString().isNotEmpty ?? false)) {
      try {
        final cover = await coverArt(
          mbid: musicBrainzCredits['releaseGroupMbid'].toString(),
          entity: 'release-group',
        );
        final coverImages = cover['images'];
        if (coverImages is List) {
          for (final raw in coverImages.whereType<Map>()) {
            final map = Map<String, dynamic>.from(raw);
            final candidate = (map['thumbnail500'] ?? map['thumbnail250'] ?? map['image'])?.toString() ?? '';
            if (candidate.startsWith('https://')) {
              imageUrl = candidate;
              break;
            }
          }
        }
      } catch (_) {
        // Keep album metadata usable when no Cover Art Archive image exists.
      }
    }
    final label = album['label']?.toString().trim().isNotEmpty == true
        ? album['label'].toString()
        : musicBrainzCredits['label']?.toString() ?? '';
    return <String, dynamic>{
      'success': true,
      'source': 'Spotify',
      'metadataSources': <String>['Spotify', if ((musicBrainzCredits['releaseGroupMbid']?.toString().isNotEmpty ?? false)) 'MusicBrainz'],
      'id': id,
      'title': albumTitle,
      'albumType': album['album_type']?.toString() ?? 'album',
      'releaseDate': album['release_date']?.toString() ?? '',
      'releaseDatePrecision': album['release_date_precision']?.toString() ?? '',
      'totalTracks': album['total_tracks'] ?? tracks.length,
      'artists': _spotifyArtistObjects(album['artists']),
      'artist': artistNames,
      'imageUrl': imageUrl,
      'images': images,
      'spotifyUrl': _spotifyExternalUrl(album),
      'label': label,
      'copyrights': album['copyrights'] is List
          ? (album['copyrights'] as List).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
          : <Map<String, dynamic>>[],
      'composers': musicBrainzCredits['composers'] ?? <String>[],
      'producers': musicBrainzCredits['producers'] ?? <String>[],
      'musicBrainzReleaseGroupMbid': musicBrainzCredits['releaseGroupMbid'] ?? '',
      'musicBrainzReleaseUrl': musicBrainzCredits['releaseUrl'] ?? '',
      'musicBrainzReleaseCredits': musicBrainzCredits['releaseCredits'] ?? <Map<String, dynamic>>[],
      'musicBrainzReleaseDetails': musicBrainzCredits['releaseDetails'] ?? <String, dynamic>{},
      'musicBrainzTrackCreditCount': musicBrainzCredits['trackCreditCount'] ?? 0,
      'creditNote': musicBrainzCredits['creditNote'] ?? 'MusicBrainz release credits are unavailable for this album match.',
      'tracks': tracks,
      'trackCountReturned': tracks.length,
      'trackWarning': trackWarning,
      'attribution': 'Album and track metadata/artwork are provided by Spotify. Release edition details and role-by-role credits are from MusicBrainz when an exact release match is available.',
    };
  }

  Future<Map<String, dynamic>> _musicBrainzAlbumCredits({
    required String albumTitle,
    required String artistNames,
    required String releaseDate,
    required List<Map<String, dynamic>> spotifyTracks,
  }) async {
    String escape(String value) => value
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"');
    String normalize(String value) => value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"), '');

    String displayRole(String rawType, List<String> attributes) {
      final type = rawType.toLowerCase().trim().replaceAll('-', ' ');
      const fixedRoles = <String, String>{
        'mix': 'Mixer',
        'mastering': 'Mastering engineer',
        'recording': 'Recording engineer',
        'phonographic copyright': 'Phonographic copyright (℗) by',
        'copyright': 'Copyright (©) by',
        'license': 'Licensed to',
        'licensed to': 'Licensed to',
        'distribute': 'Distributed by',
        'distributed by': 'Distributed by',
        'producer': 'Producer',
        'executive producer': 'Executive producer',
        'assistant producer': 'Assistant producer',
        'composer': 'Composer',
        'lyricist': 'Lyricist',
        'writer': 'Writer',
        'engineer': 'Engineer',
        'performer': 'Performer',
        'vocal': 'Vocals',
        'instrument': 'Instrument',
        'remixer': 'Remixer',
        'arranger': 'Arranger',
        'conductor': 'Conductor',
        'orchestrator': 'Orchestrator',
        'miscellaneous support': 'Miscellaneous support',
        'mastering engineer': 'Mastering engineer',
        'recording engineer': 'Recording engineer',
      };
      final qualifiers = attributes
          .where((value) => const <String>{'assistant', 'associate', 'additional', 'co', 'executive', 'remix'}.contains(value.toLowerCase().trim()))
          .map((value) => value.toLowerCase().trim())
          .toList();
      final base = fixedRoles[type] ?? (type.isEmpty ? 'Credit' : type[0].toUpperCase() + type.substring(1));
      if (qualifiers.isEmpty) return base;
      final prefix = qualifiers.map((value) => value == 'co' ? 'Co-' : value[0].toUpperCase() + value.substring(1)).join(' ');
      return '$prefix $base';
    }

    final wantedTitle = normalize(albumTitle);
    if (wantedTitle.isEmpty) return <String, dynamic>{};
    final firstArtist = artistNames.split(',').first.trim();
    final query = firstArtist.isEmpty
        ? 'releasegroup:"${escape(albumTitle)}"'
        : 'releasegroup:"${escape(albumTitle)}" AND artist:"${escape(firstArtist)}"';
    final search = await _musicBrainzGet(Uri.https(
      'musicbrainz.org',
      '/ws/2/release-group/',
      <String, String>{'query': query, 'fmt': 'json', 'limit': '10'},
    ));
    final rawGroups = search['release-groups'];
    if (rawGroups is! List) return <String, dynamic>{};
    final groups = rawGroups.whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .where((v) => normalize(v['title']?.toString() ?? '') == wantedTitle)
        .toList();
    if (groups.isEmpty) return <String, dynamic>{};

    // Prefer the exact credited artist when several release groups share a title.
    final normalizedArtists = artistNames.split(',').map(normalize).where((v) => v.isNotEmpty).toSet();
    final group = groups.firstWhere((candidate) {
      final credits = candidate['artist-credit'];
      if (credits is! List) return false;
      final creditedNames = credits.whereType<Map>().map((credit) {
        final artist = credit['artist'];
        return normalize(artist is Map ? (artist['name']?.toString() ?? '') : (credit['name']?.toString() ?? ''));
      }).where((v) => v.isNotEmpty).toSet();
      return normalizedArtists.isEmpty || creditedNames.isEmpty || creditedNames.intersection(normalizedArtists).isNotEmpty;
    }, orElse: () => groups.first);
    final groupId = group['id']?.toString() ?? '';
    if (!_isMbid(groupId)) return <String, dynamic>{};

    final browse = await _musicBrainzGet(Uri.https(
      'musicbrainz.org',
      '/ws/2/release/',
      <String, String>{
        'release-group': groupId,
        'fmt': 'json',
        'limit': '10',
        'inc': 'artist-credits+labels+recordings+media+release-groups+discids+isrcs+release-rels+recording-rels+work-rels+recording-level-rels+release-group-level-rels+work-level-rels',
      },
    ));
    final rawReleases = browse['releases'];
    if (rawReleases is! List || rawReleases.isEmpty) {
      return <String, dynamic>{
        'releaseGroupMbid': groupId,
        'releaseUrl': 'https://musicbrainz.org/release-group/$groupId',
        'composers': <String>[],
        'producers': <String>[],
        'releaseCredits': <Map<String, dynamic>>[],
        'creditNote': 'MusicBrainz matched this album but returned no detailed release credits.',
      };
    }

    final releases = rawReleases.whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v)).toList();
    final targetYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    int releaseScore(Map<String, dynamic> value) {
      var score = 0;
      if ((value['status']?.toString().toLowerCase() ?? '') == 'official') score += 10;
      if (targetYear.isNotEmpty && (value['date']?.toString() ?? '').startsWith(targetYear)) score += 20;
      if ((value['country']?.toString() ?? '') == 'XW') score -= 1;
      return score;
    }
    releases.sort((a, b) => releaseScore(b).compareTo(releaseScore(a)));
    final release = releases.first;
    final releaseId = release['id']?.toString() ?? '';

    final albumRoleMap = <String, Set<String>>{};
    final perTrackCredits = <String, Map<String, Set<String>>>{};
    final perTrackMbids = <String, String>{};
    final perTrackIsrcs = <String, List<String>>{};

    void addRole(Map<String, Set<String>> destination, String role, String person) {
      final cleanRole = role.trim();
      final cleanPerson = person.trim();
      if (cleanRole.isEmpty || cleanPerson.isEmpty) return;
      destination.putIfAbsent(cleanRole, () => <String>{}).add(cleanPerson);
    }

    void readRelations(dynamic node, Map<String, Set<String>> destination, [int depth = 0]) {
      if (node is! Map || depth > 5) return;
      final row = Map<String, dynamic>.from(node);
      final relations = row['relations'];
      if (relations is! List) return;
      for (final rawRelation in relations.whereType<Map>()) {
        final relation = Map<String, dynamic>.from(rawRelation);
        final type = (relation['type'] ?? relation['type-name'] ?? '').toString().trim();
        final attrs = relation['attributes'] is List
            ? (relation['attributes'] as List).map((value) => value.toString()).toList()
            : <String>[];
        final artist = relation['artist'] is Map
            ? Map<String, dynamic>.from(relation['artist'] as Map)
            : <String, dynamic>{};
        final labelTarget = relation['label'] is Map
            ? Map<String, dynamic>.from(relation['label'] as Map)
            : <String, dynamic>{};
        final name = artist['name']?.toString().trim().isNotEmpty == true
            ? artist['name'].toString().trim()
            : labelTarget['name']?.toString().trim() ?? '';
        if (name.isNotEmpty && type.isNotEmpty) {
          final role = displayRole(type, attrs);
          // MusicBrainz stores instrument/vocal specifics as relationship attributes.
          final nonQualifierAttrs = attrs.where((value) => !const <String>{'assistant', 'associate', 'additional', 'co', 'executive', 'remix'}.contains(value.toLowerCase().trim())).toList();
          if ((type.toLowerCase() == 'instrument' || type.toLowerCase() == 'vocal') && nonQualifierAttrs.isNotEmpty) {
            for (final detail in nonQualifierAttrs) {
              final detailRole = detail.isEmpty ? role : detail[0].toUpperCase() + detail.substring(1);
              addRole(destination, detailRole, name);
            }
          } else {
            addRole(destination, role, name);
          }
        }
        // Recording relationships can point to a work; the work contains writer,
        // composer and lyricist credits. Walk only that bounded relationship tree.
        if (relation['work'] is Map) readRelations(relation['work'], destination, depth + 1);
      }
    }

    // Capture all personnel and company credits attached directly to this release
    // and to the linked release group. These are separate from track-specific roles.
    readRelations(release, albumRoleMap);
    if (release['release-group'] is Map) {
      readRelations(release['release-group'], albumRoleMap);
    }

    final releaseMedia = release['media'] is List
        ? (release['media'] as List).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
        : <Map<String, dynamic>>[];
    final mediaFormats = <String>{};
    var mbTrackCount = 0;
    for (final medium in releaseMedia) {
      final format = medium['format']?.toString().trim() ?? '';
      if (format.isNotEmpty) mediaFormats.add(format);
      final tracksRaw = medium['tracks'] is List ? medium['tracks'] as List : <dynamic>[];
      mbTrackCount += int.tryParse(medium['track-count']?.toString() ?? '') ?? tracksRaw.length;
      for (final rawTrack in tracksRaw.whereType<Map>()) {
        final track = Map<String, dynamic>.from(rawTrack);
        final recording = track['recording'] is Map
            ? Map<String, dynamic>.from(track['recording'] as Map)
            : <String, dynamic>{};
        final trackTitle = (recording['title'] ?? track['title'] ?? '').toString();
        final key = normalize(trackTitle);
        if (key.isEmpty) continue;
        final credits = perTrackCredits.putIfAbsent(key, () => <String, Set<String>>{});
        readRelations(recording, credits);
        readRelations(track, credits);
        final recordingId = recording['id']?.toString() ?? '';
        if (recordingId.isNotEmpty) perTrackMbids[key] = recordingId;
        final isrcRows = recording['isrcs'] is List ? (recording['isrcs'] as List).map((value) => value.toString()).where((value) => value.trim().isNotEmpty).toList() : <String>[];
        if (isrcRows.isNotEmpty) perTrackIsrcs[key] = isrcRows.toSet().toList()..sort();
      }
    }

    // Preserve the old convenience arrays while attaching the full role list to
    // each matching Spotify track without altering Spotify's canonical title.
    for (final track in spotifyTracks) {
      final key = normalize(track['title']?.toString() ?? '');
      final roles = perTrackCredits[key] ?? <String, Set<String>>{};
      List<String> valuesFor(bool Function(String role) predicate) => roles.entries
          .where((entry) => predicate(entry.key.toLowerCase()))
          .expand((entry) => entry.value)
          .toSet()
          .toList()..sort();
      track['producers'] = valuesFor((role) => role.contains('producer'));
      track['composers'] = valuesFor((role) => role.contains('composer') || role.contains('writer') || role.contains('lyricist'));
      track['performers'] = valuesFor((role) => role.contains('performer') || role.contains('vocal') || role.contains('guitar') || role.contains('drum') || role.contains('piano') || role.contains('cello') || role.contains('saxophone'));
      track['musicBrainzRecordingMbid'] = perTrackMbids[key] ?? '';
      track['isrcs'] = perTrackIsrcs[key] ?? <String>[];
      track['musicBrainzCredits'] = roles.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) => <String, dynamic>{'role': entry.key, 'people': entry.value.toList()..sort()})
          .toList()
        ..sort((a, b) => (a['role']?.toString() ?? '').compareTo(b['role']?.toString() ?? ''));
    }

    final labelsRaw = release['label-info'] is List ? release['label-info'] as List : <dynamic>[];
    final labels = <String>{};
    final catalogNumbers = <String>{};
    for (final rawLabelInfo in labelsRaw.whereType<Map>()) {
      final labelInfo = Map<String, dynamic>.from(rawLabelInfo);
      final labelObject = labelInfo['label'] is Map
          ? Map<String, dynamic>.from(labelInfo['label'] as Map)
          : <String, dynamic>{};
      final labelName = labelObject['name']?.toString().trim() ?? '';
      final catalogNumber = labelInfo['catalog-number']?.toString().trim() ?? '';
      if (labelName.isNotEmpty) labels.add(labelName);
      if (catalogNumber.isNotEmpty) catalogNumbers.add(catalogNumber);
    }
    final releaseGroup = release['release-group'] is Map
        ? Map<String, dynamic>.from(release['release-group'] as Map)
        : group;
    final releaseUrl = releaseId.isEmpty
        ? 'https://musicbrainz.org/release-group/$groupId'
        : 'https://musicbrainz.org/release/$releaseId';
    final releaseCredits = albumRoleMap.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => <String, dynamic>{'role': entry.key, 'people': entry.value.toList()..sort()})
        .toList()
      ..sort((a, b) => (a['role']?.toString() ?? '').compareTo(b['role']?.toString() ?? ''));
    final producers = <String>{};
    final composers = <String>{};
    void aggregateAlbumRole(String role, Iterable<String> people) {
      final normalizedRole = role.toLowerCase();
      if (normalizedRole.contains('producer')) producers.addAll(people);
      if (normalizedRole.contains('composer') || normalizedRole.contains('writer') || normalizedRole.contains('lyricist')) composers.addAll(people);
    }
    for (final row in releaseCredits) {
      final role = row['role']?.toString() ?? '';
      final people = row['people'] is List ? (row['people'] as List).map((v) => v.toString()) : const <String>[];
      aggregateAlbumRole(role, people);
    }
    for (final track in spotifyTracks) {
      final rows = track['musicBrainzCredits'];
      if (rows is! List) continue;
      for (final rawRow in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(rawRow);
        final people = row['people'] is List ? (row['people'] as List).map((v) => v.toString()) : const <String>[];
        aggregateAlbumRole(row['role']?.toString() ?? '', people);
      }
    }
    final primaryType = releaseGroup['primary-type']?.toString() ?? '';
    final secondaryTypes = releaseGroup['secondary-types'] is List
        ? (releaseGroup['secondary-types'] as List).map((v) => v.toString()).toList()
        : <String>[];
    final trackCreditCount = spotifyTracks.fold<int>(0, (count, track) => count + ((track['musicBrainzCredits'] is List) ? (track['musicBrainzCredits'] as List).length : 0));
    return <String, dynamic>{
      'releaseGroupMbid': groupId,
      'releaseId': releaseId,
      'releaseUrl': releaseUrl,
      'label': labels.join(', '),
      'producers': producers.toList()..sort(),
      'composers': composers.toList()..sort(),
      'releaseCredits': releaseCredits,
      'releaseDetails': <String, dynamic>{
        'date': release['date']?.toString() ?? '',
        'country': release['country']?.toString() ?? '',
        'status': release['status']?.toString() ?? '',
        'barcode': release['barcode']?.toString() ?? '',
        'packaging': release['packaging']?.toString() ?? '',
        'format': mediaFormats.toList()..sort(),
        'catalogNumbers': catalogNumbers.toList()..sort(),
        'disambiguation': release['disambiguation']?.toString() ?? '',
        'trackCount': mbTrackCount,
        'mediumCount': releaseMedia.length,
        'primaryType': primaryType,
        'secondaryTypes': secondaryTypes,
        'releaseGroupFirstDate': releaseGroup['first-release-date']?.toString() ?? '',
        'quality': release['quality']?.toString() ?? '',
      },
      'trackCreditCount': trackCreditCount,
      'creditNote': releaseCredits.isEmpty && trackCreditCount == 0
          ? 'MusicBrainz matched this album, but its selected release has no detailed personnel relationships recorded.'
          : 'Credits are grouped by role and shown for the release or individual tracks where MusicBrainz records them.',
    };
  }

  Future<Map<String, dynamic>> _spotifyGet(
    String path, {
    Map<String, String> query = const <String, String>{},
  }) async {
    final token = await _spotifyAccessToken();
    final uri = Uri.https('api.spotify.com', path, query);
    return _getJson(uri, headers: <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $token',
    });
  }

  String _validateSpotifyId(String value) {
    final id = value.trim();
    if (!RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id)) {
      throw const FormatException('A valid Spotify catalog ID is required.');
    }
    return id;
  }

  Map<String, dynamic> _spotifyAlbumSummary(Map<String, dynamic> item) {
    final images = _spotifyImages(item['images']);
    return <String, dynamic>{
      'id': item['id']?.toString() ?? '',
      'title': item['name']?.toString() ?? 'Untitled album',
      'artist': _spotifyArtistNames(item['artists']),
      'releaseDate': item['release_date']?.toString() ?? '',
      'albumType': item['album_type']?.toString() ?? item['album_group']?.toString() ?? 'album',
      'totalTracks': item['total_tracks'],
      'imageUrl': images.isNotEmpty ? images.first['url'] : '',
      'images': images,
      'spotifyUrl': _spotifyExternalUrl(item),
      'source': 'Spotify',
      'type': 'album',
    };
  }

  Map<String, dynamic> _spotifyTrackSummary(Map<String, dynamic> item) =>
      <String, dynamic>{
        'id': item['id']?.toString() ?? '',
        'title': item['name']?.toString() ?? 'Untitled track',
        'artist': _spotifyArtistNames(item['artists']),
        'durationMs': item['duration_ms'],
        'trackNumber': item['track_number'],
        'discNumber': item['disc_number'] ?? 1,
        'popularity': item['popularity'],
        'explicit': item['explicit'] == true,
        'previewUrl': _secureImageUrl(item['preview_url']?.toString()),
        'spotifyUrl': _spotifyExternalUrl(item),
        'album': item['album'] is Map
            ? ((item['album'] as Map)['name']?.toString() ?? '')
            : '',
        'imageUrl': _spotifyImage(
          item['album'] is Map ? (item['album'] as Map)['images'] : null,
        ),
        'source': 'Spotify',
        'type': 'track',
      };

  List<Map<String, dynamic>> _spotifyArtistObjects(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((raw) {
      final artist = Map<String, dynamic>.from(raw);
      return <String, dynamic>{
        'id': artist['id']?.toString() ?? '',
        'name': artist['name']?.toString() ?? '',
        'spotifyUrl': _spotifyExternalUrl(artist),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _spotifyImages(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((raw) {
      final image = Map<String, dynamic>.from(raw);
      return <String, dynamic>{
        'url': _secureImageUrl(image['url']?.toString()),
        'width': image['width'],
        'height': image['height'],
      };
    }).where((image) => (image['url']?.toString() ?? '').isNotEmpty).toList();
  }

  Future<Map<String, dynamic>?> _findTmdbPersonForArtist(String artistName) async {
    final search = await _tmdbGet('/search/person', <String, String>{
      'query': artistName,
      'include_adult': 'false',
      'page': '1',
      'language': 'en-US',
    });
    final raw = search['results'];
    if (raw is! List) return null;
    final requested = _normalizePersonName(artistName);
    final exact = raw.whereType<Map>().map((value) => Map<String, dynamic>.from(value))
        .where((value) => _normalizePersonName(value['name']?.toString() ?? '') == requested)
        .toList();
    if (exact.isEmpty) return null;
    Map<String, dynamic>? match;
    for (final candidate in exact) {
      if ((candidate['known_for_department']?.toString().toLowerCase() ?? '') == 'music') {
        match = candidate;
        break;
      }
    }
    match ??= exact.length == 1 ? exact.first : null;
    final tmdbId = int.tryParse(match?['id']?.toString() ?? '');
    if (tmdbId == null) return null;
    final details = await _tmdbGet('/person/$tmdbId', <String, String>{
      'language': 'en-US',
    });
    return details;
  }

  Future<Map<String, dynamic>> _tmdbGet(
    String path,
    Map<String, String> query,
  ) async {
    final parameters = <String, String>{'language': 'en-US', ...query};
    if (tmdbApiToken.trim().isEmpty && tmdbApiKey.trim().isNotEmpty) {
      parameters['api_key'] = tmdbApiKey.trim();
    }
    final uri = Uri.https('api.themoviedb.org', '/3$path', parameters);
    final headers = <String, String>{'Accept': 'application/json'};
    if (tmdbApiToken.trim().isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer ${tmdbApiToken.trim()}';
    }
    return _getJson(uri, headers: headers);
  }

  String _tmdbProfileUrl(String? path) {
    final cleaned = path?.trim() ?? '';
    return cleaned.startsWith('/')
        ? 'https://image.tmdb.org/t/p/w342$cleaned'
        : '';
  }

  String _normalizePersonName(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"), '');

  Future<List<Map<String, dynamic>>> discography({
    required String artistMbid,
    int limit = 100,
  }) async {
    if (!_isMbid(artistMbid)) {
      throw const FormatException('A valid MusicBrainz artist MBID is required.');
    }
    final uri = Uri.https('musicbrainz.org', '/ws/2/release-group/', <String, String>{
      'artist': artistMbid,
      'fmt': 'json',
      'limit': '${limit.clamp(1, 100)}',
    });
    final payload = await _musicBrainzGet(uri);
    final raw = payload['release-groups'];
    if (raw is! List) return <Map<String, dynamic>>[];
    final items = raw.whereType<Map>().map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem);
      final mbid = item['id']?.toString() ?? '';
      final firstDate = item['first-release-date']?.toString() ?? '';
      return <String, dynamic>{
        'id': mbid,
        'title': item['title']?.toString() ?? 'Untitled release',
        'firstReleaseDate': firstDate,
        'year': firstDate.length >= 4 ? firstDate.substring(0, 4) : '',
        'primaryType': item['primary-type']?.toString() ?? 'Release',
        'secondaryTypes': item['secondary-types'] is List
            ? (item['secondary-types'] as List).map((v) => v.toString()).toList()
            : <String>[],
        'source': 'MusicBrainz',
        'coverArtUrl': _coverArtFrontUrl(mbid, entity: 'release-group'),
        'coverArtApiUrl': _coverArtApiUrl(mbid, entity: 'release-group'),
      };
    }).toList();
    items.sort((a, b) {
      final aDate = a['firstReleaseDate']?.toString() ?? '';
      final bDate = b['firstReleaseDate']?.toString() ?? '';
      if (aDate.isEmpty) return 1;
      if (bDate.isEmpty) return -1;
      return aDate.compareTo(bDate);
    });
    return items;
  }

  Future<Map<String, dynamic>> coverArt({
    required String mbid,
    String entity = 'release-group',
  }) async {
    final cleanEntity = entity.trim().toLowerCase();
    if (cleanEntity != 'release' && cleanEntity != 'release-group') {
      throw const FormatException('Cover-art entity must be release or release-group.');
    }
    if (!_isMbid(mbid)) {
      throw const FormatException('A valid MusicBrainz MBID is required.');
    }

    final endpoint = cleanEntity == 'release' ? 'release' : 'release-group';
    try {
      final payload = await _getJson(
        Uri.https('coverartarchive.org', '/$endpoint/$mbid/'),
        headers: const <String, String>{'Accept': 'application/json'},
      );
      final rawImages = payload['images'];
      final images = <Map<String, dynamic>>[];
      if (rawImages is List) {
        for (final raw in rawImages.whereType<Map>()) {
          final image = Map<String, dynamic>.from(raw);
          final thumbnails = image['thumbnails'] is Map
              ? Map<String, dynamic>.from(image['thumbnails'] as Map)
              : <String, dynamic>{};
          images.add(<String, dynamic>{
            'id': image['id']?.toString() ?? '',
            'front': image['front'] == true,
            'back': image['back'] == true,
            'types': image['types'] is List
                ? (image['types'] as List).map((v) => v.toString()).toList()
                : <String>[],
            'comment': image['comment']?.toString() ?? '',
            'edit': image['edit'],
            'image': _secureImageUrl(image['image']?.toString()),
            'thumbnail250': _secureImageUrl(
              (thumbnails['250'] ?? thumbnails['small'])?.toString(),
            ),
            'thumbnail500': _secureImageUrl(
              (thumbnails['500'] ?? thumbnails['large'])?.toString(),
            ),
            'thumbnail1200': _secureImageUrl(thumbnails['1200']?.toString()),
            'approved': image['approved'] == true,
          });
        }
      }
      // Put the community-designated front cover first when available, while
      // preserving the archive order for the remaining images.
      images.sort((a, b) {
        final frontOrder = (b['front'] == true ? 1 : 0) -
            (a['front'] == true ? 1 : 0);
        if (frontOrder != 0) return frontOrder;
        final approvedOrder = (b['approved'] == true ? 1 : 0) -
            (a['approved'] == true ? 1 : 0);
        return approvedOrder;
      });
      final releaseUrl = payload['release']?.toString() ?? '';
      return <String, dynamic>{
        'success': true,
        'found': images.isNotEmpty,
        'entity': cleanEntity,
        'mbid': mbid,
        'metadataUrl': 'https://coverartarchive.org/$endpoint/$mbid/',
        'releaseUrl': releaseUrl.startsWith('https://')
            ? releaseUrl
            : _secureImageUrl(releaseUrl),
        'images': images,
      };
    } on MusicCatalogUpstreamException catch (error) {
      if (error.statusCode == HttpStatus.notFound) {
        return <String, dynamic>{
          'success': true,
          'found': false,
          'entity': cleanEntity,
          'mbid': mbid,
          'metadataUrl': 'https://coverartarchive.org/$endpoint/$mbid/',
          'releaseUrl': '',
          'images': <Map<String, dynamic>>[],
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _searchSpotify(
    String query, {
    required String type,
    required int limit,
  }) async {
    final token = await _spotifyAccessToken();
    final spotifyType = switch (type) {
      'artist' => 'artist',
      'album' => 'album',
      'track' || 'recording' => 'track',
      _ => 'artist,album,track',
    };
    final uri = Uri.https('api.spotify.com', '/v1/search', <String, String>{
      'q': query,
      'type': spotifyType,
      'limit': '$limit',
    });
    final payload = await _getJson(uri, headers: <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $token',
    });

    List<Map<String, dynamic>> items(String key) {
      final container = payload[key] is Map
          ? Map<String, dynamic>.from(payload[key] as Map)
          : <String, dynamic>{};
      final raw = container['items'];
      return raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
    }

    return <String, dynamic>{
      'artists': items('artists').map((item) => <String, dynamic>{
        'id': item['id']?.toString() ?? '',
        'name': item['name']?.toString() ?? 'Unknown artist',
        'genres': item['genres'] is List ? (item['genres'] as List).map((v) => v.toString()).toList() : <String>[],
        'imageUrl': _spotifyImage(item['images']),
        'images': _spotifyImages(item['images']),
        'followers': item['followers'] is Map ? (item['followers'] as Map)['total'] : null,
        'popularity': item['popularity'],
        'spotifyUrl': _spotifyExternalUrl(item),
        'source': 'Spotify',
        'type': 'artist',
      }).toList(),
      'albums': items('albums').map((item) {
        final artists = _spotifyArtistNames(item['artists']);
        return <String, dynamic>{
          'id': item['id']?.toString() ?? '',
          'title': item['name']?.toString() ?? 'Untitled album',
          'artist': artists,
          'releaseDate': item['release_date']?.toString() ?? '',
          'albumType': item['album_type']?.toString() ?? 'album',
          'totalTracks': item['total_tracks'],
          'imageUrl': _spotifyImage(item['images']),
          'images': _spotifyImages(item['images']),
          'spotifyUrl': _spotifyExternalUrl(item),
          'source': 'Spotify',
          'type': 'album',
        };
      }).toList(),
      'tracks': items('tracks').map((item) {
        final album = item['album'] is Map
            ? Map<String, dynamic>.from(item['album'] as Map)
            : <String, dynamic>{};
        return <String, dynamic>{
          'id': item['id']?.toString() ?? '',
          'title': item['name']?.toString() ?? 'Untitled track',
          'artist': _spotifyArtistNames(item['artists']),
          'album': album['name']?.toString() ?? '',
          'durationMs': item['duration_ms'],
          'trackNumber': item['track_number'],
          'popularity': item['popularity'],
          'explicit': item['explicit'] == true,
          'imageUrl': _spotifyImage(album['images']),
          'images': _spotifyImages(album['images']),
          'spotifyUrl': _spotifyExternalUrl(item),
          'source': 'Spotify',
          'type': 'track',
        };
      }).toList(),
    };
  }

  Future<List<Map<String, dynamic>>> _searchMusicBrainzEntity({
    required String entity,
    required String queryField,
    required String query,
    required int limit,
    required String resultKey,
  }) async {
    final quoted = query.replaceAll('"', r'\"');
    final uri = Uri.https('musicbrainz.org', '/ws/2/$entity/', <String, String>{
      'query': '$queryField:"$quoted"',
      'fmt': 'json',
      'limit': '$limit',
    });
    final payload = await _musicBrainzGet(uri);
    final raw = payload[resultKey];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem);
      if (entity == 'artist') {
        final area = item['area'] is Map ? Map<String, dynamic>.from(item['area'] as Map) : <String, dynamic>{};
        return <String, dynamic>{
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? 'Unknown artist',
          'sortName': item['sort-name']?.toString() ?? '',
          'disambiguation': item['disambiguation']?.toString() ?? '',
          'country': item['country']?.toString() ?? '',
          'area': area['name']?.toString() ?? '',
          'artistType': item['type']?.toString() ?? '',
          'type': 'artist',
          'lifeSpan': item['life-span'] is Map ? Map<String, dynamic>.from(item['life-span'] as Map) : <String, dynamic>{},
          'source': 'MusicBrainz',
          'entityType': 'artist',
        };
      }
      if (entity == 'release-group') {
        final mbid = item['id']?.toString() ?? '';
        return <String, dynamic>{
          'id': mbid,
          'title': item['title']?.toString() ?? 'Untitled release',
          'firstReleaseDate': item['first-release-date']?.toString() ?? '',
          'primaryType': item['primary-type']?.toString() ?? 'Release',
          'secondaryTypes': item['secondary-types'] is List ? (item['secondary-types'] as List).map((v) => v.toString()).toList() : <String>[],
          'artist': _musicBrainzArtistCredits(item['artist-credit']),
          'coverArtUrl': _coverArtFrontUrl(mbid, entity: 'release-group'),
          'coverArtApiUrl': _coverArtApiUrl(mbid, entity: 'release-group'),
          'source': 'MusicBrainz',
          'type': 'album',
        };
      }
      return <String, dynamic>{
        'id': item['id']?.toString() ?? '',
        'title': item['title']?.toString() ?? 'Untitled recording',
        'artist': _musicBrainzArtistCredits(item['artist-credit']),
        'lengthMs': item['length'],
        'disambiguation': item['disambiguation']?.toString() ?? '',
        'source': 'MusicBrainz',
        'type': 'recording',
      };
    }).toList();
  }

  Future<String> _spotifyAccessToken() async {
    final currentToken = _spotifyToken;
    final expiresAt = _spotifyTokenExpiresAt;
    if (currentToken != null && expiresAt != null &&
        DateTime.now().toUtc().isBefore(expiresAt)) {
      return currentToken;
    }
    if (!spotifyConfigured) {
      throw const FormatException('Spotify credentials are not configured.');
    }

    final request = await _client.postUrl(
      Uri.https('accounts.spotify.com', '/api/token'),
    ).timeout(const Duration(seconds: 8));
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Basic ${base64Encode(utf8.encode('$spotifyClientId:$spotifyClientSecret'))}',
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-www-form-urlencoded',
    );
    request.write('grant_type=client_credentials');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
    final payload = _decodeJsonMap(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicCatalogUpstreamException(response.statusCode, 'Spotify token request failed.');
    }
    final token = payload['access_token']?.toString() ?? '';
    final expiresIn = int.tryParse(payload['expires_in']?.toString() ?? '') ?? 3600;
    if (token.isEmpty) {
      throw const FormatException('Spotify did not return an access token.');
    }
    _spotifyToken = token;
    _spotifyTokenExpiresAt = DateTime.now().toUtc().add(Duration(seconds: (expiresIn - 60).clamp(60, 86400).toInt()));
    return token;
  }

  Future<Map<String, dynamic>> _musicBrainzGet(Uri uri) {
    final completer = Completer<Map<String, dynamic>>();
    _musicBrainzQueue = _musicBrainzQueue.then((_) async {
      final elapsed = DateTime.now().toUtc().difference(_lastMusicBrainzRequestAt);
      final wait = const Duration(milliseconds: 1050) - elapsed;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        final result = await _getJson(uri, headers: <String, String>{
          HttpHeaders.userAgentHeader: userAgent,
          'Accept': 'application/json',
        });
        _lastMusicBrainzRequestAt = DateTime.now().toUtc();
        completer.complete(result);
      } catch (error, stackTrace) {
        _lastMusicBrainzRequestAt = DateTime.now().toUtc();
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.followRedirects = true;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicCatalogUpstreamException(response.statusCode, 'Music metadata provider returned HTTP ${response.statusCode}.');
    }
    return _decodeJsonMap(body);
  }

  static Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'data': decoded};
  }

  static String _normalizeType(String value) {
    final type = value.trim().toLowerCase();
    return const <String>{'all', 'artist', 'album', 'track', 'recording'}.contains(type)
        ? type
        : 'all';
  }

  static bool _isMbid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value.trim());

  static String _spotifyArtistNames(dynamic value) {
    if (value is! List) return '';
    return value.whereType<Map>().map((artist) => artist['name']?.toString() ?? '').where((name) => name.isNotEmpty).join(', ');
  }

  static String _spotifyImage(dynamic value) {
    if (value is! List || value.isEmpty) return '';
    for (final raw in value.whereType<Map>()) {
      final url = _secureImageUrl(raw['url']?.toString());
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static String _secureImageUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.startsWith('https://')) return url;
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return '';
  }

  static String _spotifyExternalUrl(Map<String, dynamic> value) {
    final external = value['external_urls'];
    if (external is! Map) return '';
    return external['spotify']?.toString() ?? '';
  }

  static String _musicBrainzArtistCredits(dynamic value) {
    if (value is! List) return '';
    final names = <String>[];
    for (final raw in value) {
      if (raw is String) {
        names.add(raw);
      } else if (raw is Map) {
        final item = Map<String, dynamic>.from(raw);
        final artist = item['artist'] is Map ? Map<String, dynamic>.from(item['artist'] as Map) : <String, dynamic>{};
        final name = (artist['name'] ?? item['name'])?.toString() ?? '';
        if (name.isNotEmpty) names.add(name);
        if (item['joinphrase'] != null && names.isNotEmpty) {
          names[names.length - 1] = '${names.last}${item['joinphrase']}';
        }
      }
    }
    return names.join();
  }

  static String _coverArtFrontUrl(String mbid, {required String entity}) =>
      mbid.isEmpty ? '' : 'https://coverartarchive.org/$entity/$mbid/front-250';

  static String _coverArtApiUrl(String mbid, {required String entity}) =>
      mbid.isEmpty ? '' : 'https://coverartarchive.org/$entity/$mbid/';
}
