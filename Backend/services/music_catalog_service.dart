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
    required this.userAgent,
    required this.tmdbApiKey,
    required this.tmdbApiToken,
  }) : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
    _client.idleTimeout = const Duration(seconds: 20);
  }

  final String spotifyClientId;
  final String spotifyClientSecret;
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

  /// Returns a page of Spotify's regional new-release album catalogue for Home.
  /// The UI can fall back to query-based search if this Spotify endpoint is
  /// unavailable to a particular developer app.
  Future<Map<String, dynamic>> featuredAlbums({
    int limit = 10,
    int offset = 0,
  }) async {
    if (!spotifyConfigured) {
      return <String, dynamic>{
        'success': true,
        'source': 'Spotify',
        'items': <Map<String, dynamic>>[],
        'total': 0,
      };
    }
    final boundedLimit = limit.clamp(1, 20).toInt();
    final boundedOffset = offset.clamp(0, 1000).toInt();
    final payload = await _spotifyGet(
      '/v1/browse/new-releases',
      query: <String, String>{
        'country': 'MX',
        'limit': '$boundedLimit',
        'offset': '$boundedOffset',
      },
    );
    final albumsPayload = payload['albums'] is Map
        ? Map<String, dynamic>.from(payload['albums'] as Map)
        : <String, dynamic>{};
    final raw = albumsPayload['items'];
    final items = raw is List
        ? raw.whereType<Map>().map((value) => _spotifyAlbumSummary(
              Map<String, dynamic>.from(value),
            )).toList(growable: false)
        : <Map<String, dynamic>>[];
    return <String, dynamic>{
      'success': true,
      'source': 'Spotify',
      'items': items,
      'count': items.length,
      'total': albumsPayload['total'] ?? items.length,
      'limit': boundedLimit,
      'offset': boundedOffset,
      'next': albumsPayload['next'],
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
      'creditNote': musicBrainzCredits['creditNote'] ?? 'Producer/composer credits are not supplied by Spotify and no exact MusicBrainz credits were found for this album.',
      'tracks': tracks,
      'trackCountReturned': tracks.length,
      'trackWarning': trackWarning,
      'attribution': 'Album and track metadata/artwork provided by Spotify; composer and producer credits, when found, are from MusicBrainz. Open the album in Spotify for the original source.',
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
    final wantedTitle = normalize(albumTitle);
    if (wantedTitle.isEmpty) return <String, dynamic>{};
    final firstArtist = artistNames.split(',').first.trim();
    final query = firstArtist.isEmpty
        ? 'releasegroup:"${escape(albumTitle)}"'
        : 'releasegroup:"${escape(albumTitle)}" AND artist:"${escape(firstArtist)}"';
    final search = await _musicBrainzGet(Uri.https(
      'musicbrainz.org',
      '/ws/2/release-group/',
      <String, String>{'query': query, 'fmt': 'json', 'limit': '5'},
    ));
    final rawGroups = search['release-groups'];
    if (rawGroups is! List) return <String, dynamic>{};
    final groups = rawGroups.whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .where((v) => normalize(v['title']?.toString() ?? '') == wantedTitle)
        .toList();
    if (groups.isEmpty) return <String, dynamic>{};
    final group = groups.first;
    final groupId = group['id']?.toString() ?? '';
    if (!_isMbid(groupId)) return <String, dynamic>{};

    final browse = await _musicBrainzGet(Uri.https(
      'musicbrainz.org',
      '/ws/2/release/',
      <String, String>{
        'release-group': groupId,
        'fmt': 'json',
        'limit': '5',
        'inc': 'artist-credits+labels+recordings+media+recording-rels+work-rels+recording-level-rels+work-level-rels',
      },
    ));
    final rawReleases = browse['releases'];
    if (rawReleases is! List || rawReleases.isEmpty) {
      return <String, dynamic>{
        'releaseGroupMbid': groupId,
        'composers': <String>[],
        'producers': <String>[],
        'creditNote': 'MusicBrainz matched this album but returned no detailed release credits.',
      };
    }
    final releases = rawReleases.whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v)).toList();
    final targetYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    releases.sort((a, b) {
      final aStatus = (a['status']?.toString().toLowerCase() == 'official') ? 0 : 1;
      final bStatus = (b['status']?.toString().toLowerCase() == 'official') ? 0 : 1;
      return aStatus.compareTo(bStatus);
    });
    final release = releases.firstWhere(
      (v) => targetYear.isNotEmpty && (v['date']?.toString() ?? '').startsWith(targetYear),
      orElse: () => releases.first,
    );
    final releaseId = release['id']?.toString() ?? '';

    final albumProducers = <String>{};
    final albumComposers = <String>{};
    final perTrackCredits = <String, Map<String, Set<String>>>{};
    void readRelations(dynamic node, Map<String, Set<String>> credits) {
      if (node is! Map) return;
      final row = Map<String, dynamic>.from(node);
      final relations = row['relations'];
      if (relations is! List) return;
      for (final rawRelation in relations.whereType<Map>()) {
        final relation = Map<String, dynamic>.from(rawRelation);
        final type = (relation['type'] ?? relation['type-name'] ?? '').toString().toLowerCase();
        final artist = relation['artist'] is Map
            ? Map<String, dynamic>.from(relation['artist'] as Map)
            : <String, dynamic>{};
        final name = artist['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          if (type.contains('producer')) credits.putIfAbsent('producers', () => <String>{}).add(name);
          if (type.contains('composer') || type.contains('writer') || type.contains('lyricist')) {
            credits.putIfAbsent('composers', () => <String>{}).add(name);
          }
          if (type.contains('performer') || type.contains('vocal')) {
            credits.putIfAbsent('performers', () => <String>{}).add(name);
          }
        }
        if (relation['work'] is Map) readRelations(relation['work'], credits);
      }
    }
    final releaseMedia = release['media'] is List
        ? (release['media'] as List).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
        : <Map<String, dynamic>>[];
    for (final medium in releaseMedia) {
      final tracksRaw = medium['tracks'] is List ? medium['tracks'] as List : <dynamic>[];
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
        albumProducers.addAll(credits['producers'] ?? const <String>{});
        albumComposers.addAll(credits['composers'] ?? const <String>{});
      }
    }
    // Attach a MusicBrainz role credit only to the corresponding track title;
    // matching by title doesn't mutate the Spotify's display title or artist.
    for (final track in spotifyTracks) {
      final key = normalize(track['title']?.toString() ?? '');
      final credits = perTrackCredits[key];
      track['producers'] = (credits?['producers'] ?? const <String>{}).toList()..sort();
      track['composers'] = (credits?['composers'] ?? const <String>{}).toList()..sort();
      track['performers'] = (credits?['performers'] ?? const <String>{}).toList()..sort();
    }
    final labelsRaw = release['label-info'] is List ? release['label-info'] as List : <dynamic>[];
    var label = '';
    for (final rawLabelInfo in labelsRaw.whereType<Map>()) {
      final labelInfo = Map<String, dynamic>.from(rawLabelInfo);
      final labelObject = labelInfo['label'] is Map
          ? Map<String, dynamic>.from(labelInfo['label'] as Map)
          : <String, dynamic>{};
      label = labelObject['name']?.toString().trim() ?? '';
      if (label.isNotEmpty) break;
    }
    final creditSourceUrl = groupId.isEmpty ? '' : 'https://musicbrainz.org/release-group/$groupId';
    return <String, dynamic>{
      'releaseGroupMbid': groupId,
      'releaseId': releaseId,
      'releaseUrl': releaseId.isEmpty ? creditSourceUrl : 'https://musicbrainz.org/release/$releaseId',
      'label': label,
      'producers': albumProducers.toList()..sort(),
      'composers': albumComposers.toList()..sort(),
      'creditNote': albumProducers.isEmpty && albumComposers.isEmpty
          ? 'MusicBrainz matched this album, but producer/composer roles were not recorded for the selected release.'
          : 'Track-level composer and producer roles are shown where MusicBrainz records them.',
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
        'explicit': item['explicit'] == true,
        'previewUrl': _secureImageUrl(item['preview_url']?.toString()),
        'spotifyUrl': _spotifyExternalUrl(item),
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
