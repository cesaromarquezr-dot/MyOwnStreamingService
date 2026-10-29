import '../../app_core.dart';

/// Live title metadata and credits from TMDB.
///
/// Uses `append_to_response` so the detail request can include credits, videos,
/// keywords, reviews and all available posters/backdrops in one API call.
class CinematicTitleMetadataService {
  CinematicTitleMetadataService._();

  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';

  // Per-process cache keeps hero/detail rebuilds from repeatedly searching TMDB.
  static final Map<String, Future<String?>> _titleLogoCache =
      <String, Future<String?>>{};
  static final Map<String, Future<Map<String, dynamic>?>> _homeMetadataCache =
      <String, Future<Map<String, dynamic>?>>{};
  static final Map<String, Future<List<CinematicTitleRecommendation>>>
      _personCreditsCache =
      <String, Future<List<CinematicTitleRecommendation>>>{};
  // Cache per region: physical release dates are territory-specific.
  static final Map<String, List<Map<String, dynamic>>> _upcomingCalendarCache =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, DateTime> _upcomingCalendarCacheUntil =
      <String, DateTime>{};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _upcomingCalendarInFlight =
      <String, Future<List<Map<String, dynamic>>>>{};

  /// TMDB requests are available when the app has an authenticated backend
  /// session; API credentials live only in Backend/.env.
  static bool get isConfigured => AppController.instance.isBackendAuthenticated;

  /// Turns a TMDB image path into a publicly loadable image URL.
  static String? imageUrl(String? path, {String size = 'w500'}) {
    final cleaned = path?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('https://') || cleaned.startsWith('http://')) {
      return cleaned;
    }
    return '$imageBaseUrl/$size/${cleaned.startsWith('/') ? cleaned.substring(1) : cleaned}';
  }

  /// Discovers a TMDB title logo for a movie or series without replacing the
  /// title in the catalog. Results are cached for this app process. The caller
  /// must have explicit artwork authorization before displaying this asset.
  static Future<String?> lookupTitleLogo({
    required String title,
    required bool isTv,
    int? year,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !isConfigured) return Future<String?>.value(null);
    final cacheKey =
        '${isTv ? 'tv' : 'movie'}|${_normalize(cleanTitle)}|${year ?? ''}';
    return _titleLogoCache.putIfAbsent(cacheKey, () async {
      try {
        final searchPath = isTv ? '/search/tv' : '/search/movie';
        var search = await _get(searchPath, <String, String>{
          'query': cleanTitle,
          'include_adult': 'false',
          'page': '1',
          'language': 'en-US',
          if (year != null) (isTv ? 'first_air_date_year' : 'year'): '$year',
        });
        var match = _findExactMatch(search['results'], cleanTitle, isTv);
        if (match == null && year != null) {
          search = await _get(searchPath, <String, String>{
            'query': cleanTitle,
            'include_adult': 'false',
            'page': '1',
            'language': 'en-US',
          });
          match = _findExactMatch(search['results'], cleanTitle, isTv);
        }
        final providerId = _toInt(match?['id']);
        if (providerId == null) return null;
        final originalLanguage = _cleanNullable(match?['original_language']);
        final imagePayload = await _get(
          isTv ? '/tv/$providerId/images' : '/movie/$providerId/images',
          <String, String>{
            'include_image_language': <String?>[
              originalLanguage,
              'en',
              'null',
            ]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .toSet()
                .join(','),
            'language': 'en-US',
          },
        );
        final logoPath = selectBestLogoPath(
          imagePayload['logos'],
          originalLanguage: originalLanguage,
        );
        return imageUrl(logoPath, size: 'original');
      } catch (_) {
        // Artwork is optional; keep the regular styled-text title available.
        return null;
      }
    });
  }

  /// Selects the most useful logo while preferring the work's original
  /// language, then language-neutral artwork, then English. Exposed separately
  /// so the ranking can be unit tested without network calls.
  static String? selectBestLogoPath(
    dynamic rawLogos, {
    String? originalLanguage,
  }) {
    final logos = _listOfMaps(rawLogos).where((row) {
      final path = row['file_path']?.toString().trim() ?? '';
      return path.isNotEmpty && path.startsWith('/');
    }).toList();
    if (logos.isEmpty) return null;
    final preferredLanguage = (originalLanguage ?? '').trim().toLowerCase();
    int languageRank(Map<String, dynamic> row) {
      final lang = (row['iso_639_1'] ?? '').toString().trim().toLowerCase();
      if (preferredLanguage.isNotEmpty && lang == preferredLanguage) return 0;
      if (lang.isEmpty || lang == 'null') return 1;
      if (lang == 'en') return 2;
      return 3;
    }

    logos.sort((a, b) {
      final languageDifference = languageRank(a).compareTo(languageRank(b));
      if (languageDifference != 0) return languageDifference;
      final aVotes = _toInt(a['vote_count']) ?? 0;
      final bVotes = _toInt(b['vote_count']) ?? 0;
      if (aVotes != bVotes) return bVotes.compareTo(aVotes);
      final aWidth = _toInt(a['width']) ?? 0;
      final bWidth = _toInt(b['width']) ?? 0;
      return bWidth.compareTo(aWidth);
    });
    return logos.first['file_path']?.toString();
  }

  /// Lightweight overview lookup for Home hero banners. Unlike [lookupTitle],
  /// this requests only search results and basic title details (plus video
  /// references) instead of loading credits, artwork galleries, keywords, and reviews.
  static Future<String?> lookupOverview({
    required String title,
    required bool isTv,
    int? year,
  }) async {
    final metadata = await lookupHomeMetadata(
      title: title,
      isTv: isTv,
      year: year,
    );
    return metadata?['overview']?.toString();
  }

  /// Lightweight exact-match metadata for the large Home hero. The title
  /// detail endpoint already carries overview, season summaries, and series
  /// run dates, avoiding a heavier cast/images/reviews lookup on Home.
  static Future<Map<String, dynamic>?> lookupHomeMetadata({
    required String title,
    required bool isTv,
    int? year,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !isConfigured) {
      return Future<Map<String, dynamic>?>.value(null);
    }
    final cacheKey =
        '${isTv ? 'tv' : 'movie'}|${_normalize(cleanTitle)}|${year ?? ''}';
    return _homeMetadataCache.putIfAbsent(cacheKey, () async {
      try {
        return await _lookupHomeMetadataUncached(
          title: cleanTitle,
          isTv: isTv,
          year: year,
        );
      } catch (_) {
        // Do not pin transient failures in cache; a later navigation can retry.
        _homeMetadataCache.remove(cacheKey);
        rethrow;
      }
    });
  }

  static Future<Map<String, dynamic>?> _lookupHomeMetadataUncached({
    required String title,
    required bool isTv,
    int? year,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !isConfigured) return null;

    final searchPath = isTv ? '/search/tv' : '/search/movie';
    Map<String, dynamic> search = await _get(searchPath, <String, String>{
      'query': cleanTitle,
      'include_adult': 'false',
      'page': '1',
      'language': 'en-US',
      if (year != null) (isTv ? 'first_air_date_year' : 'year'): '$year',
    });
    var match = _findExactMatch(search['results'], cleanTitle, isTv);

    // Catalog years can be stale; retry without the year but keep exact-title
    // matching so the hero never inherits details from a similarly named work.
    if (match == null && year != null) {
      search = await _get(searchPath, <String, String>{
        'query': cleanTitle,
        'include_adult': 'false',
        'page': '1',
        'language': 'en-US',
      });
      match = _findExactMatch(search['results'], cleanTitle, isTv);
    }
    final id = _toInt(match?['id']);
    if (id == null) return null;

    final details = await _get(
      isTv ? '/tv/$id' : '/movie/$id',
      <String, String>{
        'append_to_response': 'videos',
        'language': 'en-US',
      },
    );
    final startDate = _cleanNullable(
      details[isTv ? 'first_air_date' : 'release_date']?.toString(),
    );
    final lastAirDate =
        isTv ? _cleanNullable(details['last_air_date']?.toString()) : null;
    final status = _cleanNullable(details['status']?.toString());
    final normalizedStatus = status?.toLowerCase() ?? '';
    final ongoing = isTv &&
        <String>{
          'returning series',
          'in production',
          'planned',
          'pilot',
        }.contains(normalizedStatus);
    final startYear = _yearFromDate(startDate);
    final endYear = _yearFromDate(lastAirDate);
    final normalizedSeasons = isTv
        ? normalizeTvSeasons(details['seasons'])
        : <Map<String, dynamic>>[];
    final countedSeasons = normalizedSeasons.where((season) {
      final seasonNumber = _toInt(season['seasonNumber'] ?? season['number']);
      return seasonNumber != null && seasonNumber > 0;
    }).length;

    final videoPayload = _asMap(details['videos']);
    final previewVideos = _listOfMaps(videoPayload['results'])
        .map(CinematicTitleVideo.fromJson)
        .where((video) =>
            video.site.toLowerCase() == 'youtube' &&
            RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(video.key.trim()) &&
            <String>{'trailer', 'teaser', 'clip', 'featurette'}
                .contains(video.type.toLowerCase()))
        .toList()
      ..sort((a, b) {
        if (a.official != b.official) return a.official ? -1 : 1;
        final typeCompare =
            _videoTypePriority(a.type).compareTo(_videoTypePriority(b.type));
        if (typeCompare != 0) return typeCompare;
        return (b.publishedAt ?? '').compareTo(a.publishedAt ?? '');
      });
    final previewUrl = previewVideos.isEmpty ? null : previewVideos.first.url;

    String? runYears;
    if (isTv && startYear != null) {
      if (ongoing) {
        runYears = '$startYear–Present';
      } else if (endYear != null && endYear > startYear) {
        runYears = '$startYear–$endYear';
      } else {
        runYears = '$startYear';
      }
    } else if (!isTv) {
      runYears = startYear?.toString();
    }

    return <String, dynamic>{
      'overview': _cleanNullable(details['overview']?.toString()),
      'seasonCount': countedSeasons,
      'seasons': normalizedSeasons,
      'seriesStartYear': startYear,
      'seriesEndYear': ongoing ? null : endYear,
      'seriesOngoing': ongoing,
      'seriesStatus': status,
      'yearLabel': runYears,
      'previewUrl': previewUrl,
    };
  }

  static int? _yearFromDate(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  /// Normalizes TMDB TV season summaries into the shape used by Details.
  /// Season summaries come from GET /tv/{series_id}; episode descriptions,
  /// runtimes and stills are fetched lazily for the selected season.
  static List<Map<String, dynamic>> normalizeTvSeasons(dynamic rawSeasons) {
    final seasons = <Map<String, dynamic>>[];
    for (final row in _listOfMaps(rawSeasons)) {
      final number = _toInt(
        row['season_number'] ?? row['seasonNumber'] ?? row['number'],
      );
      if (number == null || number < 0) continue;
      final name = _cleanNullable(row['name'] ?? row['title']) ??
          (number == 0 ? 'Specials' : 'Season $number');
      final airDate = _cleanNullable(row['air_date'] ?? row['airDate']);
      final overview = _cleanNullable(row['overview'] ?? row['description']);
      seasons.add(<String, dynamic>{
        'id': row['id']?.toString(),
        'seasonNumber': number,
        'season_number': number,
        'number': number,
        'name': name,
        'title': name,
        'airDate': airDate,
        'air_date': airDate,
        'episodeCount':
            _toInt(row['episode_count'] ?? row['episodeCount']) ?? 0,
        'overview': overview,
        'description': overview,
        'posterUrl': imageUrl(
          row['poster_path']?.toString() ?? row['posterUrl']?.toString(),
          size: 'w342',
        ),
        'metadataSource': 'TMDB',
        'episodes': <Map<String, dynamic>>[],
      });
    }
    seasons.sort((a, b) => (_toInt(a['seasonNumber']) ?? 0)
        .compareTo(_toInt(b['seasonNumber']) ?? 0));
    return seasons;
  }

  /// Fetches detailed episode credits for one season through the authenticated
  /// backend proxy. It never contacts TMDB directly from the Flutter client.
  static Future<List<Map<String, dynamic>>> lookupTvSeasonEpisodes({
    required int providerId,
    required int seasonNumber,
  }) async {
    if (!isConfigured || providerId <= 0 || seasonNumber < 0) {
      return <Map<String, dynamic>>[];
    }
    final payload = await _get('/tv/$providerId/season/$seasonNumber');
    return normalizeTvSeasonEpisodes(payload, seasonNumber: seasonNumber);
  }

  /// Pure mapping helper kept separate so episode numbering, descriptions,
  /// runtimes, and image URLs can be regression-tested without network access.
  static List<Map<String, dynamic>> normalizeTvSeasonEpisodes(
    Map<String, dynamic> payload, {
    required int seasonNumber,
  }) {
    final normalized = <Map<String, dynamic>>[];
    for (final row in _listOfMaps(payload['episodes'])) {
      final title = _cleanNullable(row['name'] ?? row['title']);
      final episodeNumber = _toInt(
        row['episode_number'] ?? row['episodeNumber'] ?? row['number'],
      );
      if (title == null || title.isEmpty || episodeNumber == null) continue;
      final airDate = _cleanNullable(row['air_date'] ?? row['airDate']);
      final runtime = _positiveIntOrNull(
        row['runtime'] ?? row['runtimeMinutes'] ?? row['duration'],
      );
      final id = _toInt(row['id']);
      final seasonId = row['season_id'] ?? row['seasonId'];
      final overview = _cleanNullable(row['overview'] ?? row['description']);
      normalized.add(<String, dynamic>{
        'id': id?.toString() ??
            'tmdb-season-$seasonNumber-episode-$episodeNumber',
        'providerEpisodeId': id,
        'seasonNumber':
            _toInt(row['season_number'] ?? row['seasonNumber']) ?? seasonNumber,
        'season':
            _toInt(row['season_number'] ?? row['seasonNumber']) ?? seasonNumber,
        'episodeNumber': episodeNumber,
        'episode_number': episodeNumber,
        'number': episodeNumber,
        'episodeCode':
            'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}',
        'title': title,
        'name': title,
        'description': overview,
        'overview': overview,
        'airDate': airDate,
        'air_date': airDate,
        'releaseYear': airDate != null && airDate.length >= 4
            ? int.tryParse(airDate.substring(0, 4))
            : null,
        'runtime': runtime,
        'runtimeMinutes': runtime,
        'duration': runtime,
        'imageUrl': imageUrl(
          row['still_path']?.toString() ?? row['imageUrl']?.toString(),
          size: 'w300',
        ),
        'rating': _doubleOrNull(row['vote_average'] ?? row['rating']),
        'voteCount': _toInt(row['vote_count'] ?? row['voteCount']) ?? 0,
        'productionCode':
            _cleanNullable(row['production_code'] ?? row['productionCode']),
        'seasonId': seasonId?.toString(),
        'metadataSource': 'TMDB',
        'metadataOnly': true,
      });
    }
    normalized.sort((a, b) => (_toInt(a['episodeNumber']) ?? 0)
        .compareTo(_toInt(b['episodeNumber']) ?? 0));
    return normalized;
  }

  static Future<CinematicTitleMetadata?> lookupTitle({
    required String title,
    required bool isTv,
    int? year,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !isConfigured) return null;

    final searchPath = isTv ? '/search/tv' : '/search/movie';
    final query = <String, String>{
      'query': cleanTitle,
      'include_adult': 'false',
      'page': '1',
      'language': 'en-US',
      if (year != null)
        (isTv ? 'first_air_date_year' : 'year'): year.toString(),
    };
    var search = await _get(searchPath, query);
    var results = search['results'];
    var exactMatch = _findExactMatch(results, cleanTitle, isTv);

    // A year hint can be stale or missing. Retry without it, but still require
    // an exact normalized title match to avoid displaying another work's data.
    if (exactMatch == null && year != null) {
      search = await _get(searchPath, <String, String>{
        'query': cleanTitle,
        'include_adult': 'false',
        'page': '1',
        'language': 'en-US',
      });
      results = search['results'];
      exactMatch = _findExactMatch(results, cleanTitle, isTv);
    }
    if (exactMatch == null) return null;

    final id = _toInt(exactMatch['id']);
    if (id == null) return null;
    final detailsPath = isTv ? '/tv/$id' : '/movie/$id';
    final details = await _get(detailsPath, <String, String>{
      'append_to_response':
          'credits,videos,keywords,reviews,images,external_ids',
      'include_image_language':
          'ar,bg,bn,cs,da,de,el,en,es,et,fa,fi,fr,he,hi,hr,hu,id,it,ja,ka,kk,ko,lt,lv,ml,mr,ms,nb,nl,pl,pt,ro,ru,sk,sl,sr,sv,ta,te,th,tr,uk,vi,zh,null',
      'language': 'en-US',
    });

    final credits = _asMap(details['credits']);
    final castRows = _listOfMaps(credits['cast']);
    final crewRows = _listOfMaps(credits['crew']);
    // Keep the complete sourced cast credit (character and portrait included)
    // for X-Ray. The simpler name/character lists remain for existing callers.
    final castCredits = castRows
        .map(CinematicCastCredit.fromJson)
        .where((credit) => credit.name.isNotEmpty)
        .toList(growable: false);

    final cast = <String>[];
    final characters = <String>[];
    for (final row in castRows.take(20)) {
      final name = row['name']?.toString().trim() ?? '';
      final character = row['character']?.toString().trim() ?? '';
      if (name.isNotEmpty && !cast.contains(name)) cast.add(name);
      if (character.isNotEmpty && !characters.contains(character)) {
        characters.add(character);
      }
    }

    final directors = <String>[];
    final writers = <String>[];
    final music = <String>[];
    for (final row in crewRows) {
      final name = row['name']?.toString().trim() ?? '';
      final job = row['job']?.toString().trim().toLowerCase() ?? '';
      if (name.isEmpty) continue;
      if (job == 'director' || job == 'series director') {
        if (!directors.contains(name)) directors.add(name);
      }
      if (const <String>{
        'writer',
        'screenplay',
        'story',
        'teleplay',
        'adaptation',
      }.contains(job)) {
        if (!writers.contains(name)) writers.add(name);
      }
      if (job.contains('music') || job == 'composer') {
        if (!music.contains(name)) music.add(name);
      }
    }

    // Display metadata should prefer the work's original-language title.
    // The app's own MediaItem.title remains authoritative in the UI; this
    // provider title is used for metadata/test output, not to rename a record.
    final actualTitle = (isTv
            ? details['original_name'] ?? details['name']
            : details['original_title'] ?? details['title'])
        ?.toString()
        .trim();
    final releaseDate =
        (isTv ? details['first_air_date'] : details['release_date'])
            ?.toString();
    final lastAirDate = isTv ? details['last_air_date']?.toString() : null;
    final imagePayload = _asMap(details['images']);
    final externalIds = _asMap(details['external_ids']);

    final logoRows = _listOfMaps(imagePayload['logos']);
    final rankedLogoPaths = <String?>[
      selectBestLogoPath(logoRows,
          originalLanguage: details['original_language']?.toString()),
      ...logoRows.map((row) => row['file_path']?.toString()),
    ];
    final logoPaths = _uniqueStrings(rankedLogoPaths);
    final posterPaths = _uniqueStrings(<String?>[
      details['poster_path']?.toString(),
      ..._listOfMaps(imagePayload['posters'])
          .map((row) => row['file_path']?.toString()),
    ]);
    final backdropPaths = _uniqueStrings(<String?>[
      details['backdrop_path']?.toString(),
      ..._listOfMaps(imagePayload['backdrops'])
          .map((row) => row['file_path']?.toString()),
    ]);

    final keywordPayload = details['keywords'];
    final keywordMap = _asMap(keywordPayload);
    final keywordRows = _listOfMaps(
      keywordPayload is List
          ? keywordPayload
          : (keywordMap['keywords'] ?? keywordMap['results']),
    );
    final keywords = _uniqueStrings(
      keywordRows.map((row) => row['name']?.toString()),
    );

    final genreRows = _listOfMaps(details['genres']);
    final genres = _uniqueStrings(
      genreRows.map((row) => row['name']?.toString()),
    );

    final videoPayload = _asMap(details['videos']);
    final videos = _listOfMaps(videoPayload['results'])
        .map(CinematicTitleVideo.fromJson)
        .where((video) => video.key.trim().isNotEmpty && video.url != null)
        .toList()
      ..sort((a, b) {
        if (a.official != b.official) return a.official ? -1 : 1;
        final aPriority = _videoTypePriority(a.type);
        final bPriority = _videoTypePriority(b.type);
        return aPriority.compareTo(bPriority);
      });

    final reviewPayload = _asMap(details['reviews']);
    final reviews = _listOfMaps(reviewPayload['results'])
        .map(CinematicTitleReview.fromJson)
        .where((review) => review.content.trim().isNotEmpty)
        .toList();

    final runtime = isTv
        ? _firstPositiveInt(details['episode_run_time'])
        : _positiveIntOrNull(details['runtime']);
    final tvSeasons = isTv
        ? normalizeTvSeasons(details['seasons'])
        : <Map<String, dynamic>>[];
    final originCountryValues = isTv
        ? (details['origin_country'] is List
            ? (details['origin_country'] as List)
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList()
            : <String>[])
        : _listOfMaps(details['production_countries'])
            .map((row) => _cleanNullable(row['name'] ?? row['iso_3166_1']))
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toList();
    final countryOfOrigin = originCountryValues
        .map((value) => _countryName(value))
        .toSet()
        .join(', ');

    return CinematicTitleMetadata(
      providerId: id,
      imdbId: _cleanNullable(externalIds['imdb_id']),
      title: actualTitle?.isNotEmpty == true ? actualTitle! : cleanTitle,
      isTv: isTv,
      countryOfOrigin: countryOfOrigin.isEmpty ? null : countryOfOrigin,
      overview: details['overview']?.toString() ?? '',
      posterPath: _cleanNullable(details['poster_path']),
      backdropPath: _cleanNullable(details['backdrop_path']),
      releaseDate: releaseDate?.isNotEmpty == true ? releaseDate : null,
      lastAirDate: lastAirDate?.trim().isNotEmpty == true ? lastAirDate : null,
      originalTitle: _cleanNullable(
        isTv ? details['original_name'] : details['original_title'],
      ),
      tagline: _cleanNullable(details['tagline']),
      homepage: _cleanNullable(details['homepage']),
      status: _cleanNullable(details['status']),
      originalLanguage: _cleanNullable(details['original_language']),
      voteAverage: _doubleOrNull(details['vote_average']),
      voteCount: _positiveIntOrNull(details['vote_count']),
      budget: _positiveIntOrNull(details['budget']),
      revenue: _positiveIntOrNull(details['revenue']),
      runtimeMinutes: runtime,
      genres: genres,
      keywords: keywords,
      posterPaths: posterPaths,
      backdropPaths: backdropPaths,
      logoPaths: logoPaths,
      videos: videos,
      reviews: reviews,
      cast: cast,
      characters: characters,
      castCredits: castCredits,
      crewCredits: crewRows
          .map(CinematicCrewCredit.fromJson)
          .where((credit) => credit.name.isNotEmpty)
          .toList(growable: false),
      seasons: tvSeasons,
      directors: directors,
      writers: writers,
      music: music,
    );
  }

  /// Returns one page of TMDB community reviews. The review screen pages through
  /// every result reported by TMDB instead of silently truncating the response
  /// to the first five review cards.
  /// Compatibility API used by ReviewsHubScreen for paginated provider reviews.
  static Future<CinematicTitleReviewPage> lookupReviewsPage({
    required int providerId,
    required bool isTv,
    int page = 1,
  }) async {
    if (!isConfigured || providerId <= 0 || page < 1) {
      return const CinematicTitleReviewPage(
        page: 1,
        totalPages: 0,
        totalResults: 0,
        reviews: <CinematicTitleReview>[],
      );
    }
    final path =
        isTv ? '/tv/$providerId/reviews' : '/movie/$providerId/reviews';
    final payload = await _get(path, <String, String>{'page': '$page'});
    final reviews = _listOfMaps(payload['results'])
        .map(CinematicTitleReview.fromJson)
        .where((review) => review.content.trim().isNotEmpty)
        .toList(growable: false);
    return CinematicTitleReviewPage(
      page: _toInt(payload['page']) ?? page,
      totalPages: _positiveIntOrNull(payload['total_pages']) ?? 0,
      totalResults:
          _positiveIntOrNull(payload['total_results']) ?? reviews.length,
      reviews: List<CinematicTitleReview>.unmodifiable(reviews),
    );
  }

  /// Returns TMDB's title-to-title recommendations for a matched movie or TV show.
  /// This is separate from the metadata payload because TMDB exposes it as a
  /// dedicated `/recommendations` endpoint.
  static Future<List<CinematicTitleRecommendation>> lookupRecommendations({
    required int providerId,
    required bool isTv,
    int limit = 20,
  }) async {
    if (!isConfigured || providerId <= 0 || limit <= 0) {
      return const <CinematicTitleRecommendation>[];
    }
    final path = isTv
        ? '/tv/$providerId/recommendations'
        : '/movie/$providerId/recommendations';
    final payload = await _get(path, <String, String>{'page': '1'});
    final seenIds = <int>{providerId};
    final output = <CinematicTitleRecommendation>[];
    for (final row in _listOfMaps(payload['results'])) {
      final recommendation = CinematicTitleRecommendation.fromJson(
        row,
        isTv: isTv,
      );
      if (recommendation.providerId <= 0 ||
          recommendation.title.trim().isEmpty ||
          !seenIds.add(recommendation.providerId)) {
        continue;
      }
      output.add(recommendation);
      if (output.length >= limit) break;
    }
    return List<CinematicTitleRecommendation>.unmodifiable(output);
  }

  /// Returns a person's combined movie and TV credits from TMDB.
  /// Keeping the person-specific call here means the client never needs a TMDB API key.
  static Future<List<CinematicTitleRecommendation>> lookupPersonCredits({
    required int personId,
    int limit = 24,
  }) async {
    if (!isConfigured || personId <= 0 || limit <= 0) {
      return const <CinematicTitleRecommendation>[];
    }
    final cacheKey = '$personId:$limit';
    return _personCreditsCache.putIfAbsent(cacheKey, () async {
      try {
        final payload = await _get(
          '/person/$personId/combined_credits',
          const <String, String>{'language': 'en-US'},
        );
        final rows = <Map<String, dynamic>>[
          ..._listOfMaps(payload['cast']),
          ..._listOfMaps(payload['crew']),
        ];
        final seen = <String>{};
        final results = <CinematicTitleRecommendation>[];
        for (final row in rows) {
          if (row['adult'] == true) continue;
          final mediaType = row['media_type']?.toString().trim().toLowerCase();
          if (mediaType != 'movie' && mediaType != 'tv') continue;
          final isTv = mediaType == 'tv';
          final item = CinematicTitleRecommendation.fromJson(row, isTv: isTv);
          final key = '$mediaType:${item.providerId}';
          if (item.providerId <= 0 ||
              item.title.trim().isEmpty ||
              !seen.add(key)) {
            continue;
          }
          results.add(item);
        }
        results.sort((a, b) {
          final byVotes = (b.voteCount ?? 0).compareTo(a.voteCount ?? 0);
          if (byVotes != 0) return byVotes;
          final byRating = (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0);
          if (byRating != 0) return byRating;
          return (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
        });
        return List<CinematicTitleRecommendation>.unmodifiable(
          results.take(limit),
        );
      } catch (_) {
        // Person filmography is a discovery enhancement; the rest of Home stays usable.
        return const <CinematicTitleRecommendation>[];
      }
    });
  }

  /// Mood-based discovery recommendations for the "Or maybe something a bit
  /// more..." picker. Uses TMDB's discover endpoints and mood-to-genre mapping.
  /// The made-for-TV mood intentionally discovers TV movies from the movie API,
  /// even when the title that opened the screen is a TV series.
  static Future<List<CinematicTitleRecommendation>> lookupMoodRecommendations({
    required String moodKey,
    required int sourceProviderId,
    required bool sourceIsTv,
    int limit = 20,
  }) async {
    if (!isConfigured || sourceProviderId <= 0 || limit <= 0) {
      return const <CinematicTitleRecommendation>[];
    }
    final mood = CinematicRecommendationMood.byKey(moodKey);
    if (mood == null) return const <CinematicTitleRecommendation>[];

    final discoverIsTv = mood.forceMovie ? false : sourceIsTv;
    final genreId = discoverIsTv ? mood.tvGenreId : mood.movieGenreId;
    final path = discoverIsTv ? '/discover/tv' : '/discover/movie';
    final query = <String, String>{
      'page': '1',
      'include_adult': 'false',
      'sort_by': mood.key == 'current'
          ? (discoverIsTv ? 'first_air_date.desc' : 'primary_release_date.desc')
          : 'popularity.desc',
      'vote_count.gte': '10',
    };
    if (genreId > 0) query['with_genres'] = genreId.toString();
    if (mood.key == 'current') {
      final today = DateTime.now();
      final cutoff = today.subtract(const Duration(days: 730));
      String dateString(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      final datePrefix =
          discoverIsTv ? 'first_air_date' : 'primary_release_date';
      query['$datePrefix.gte'] = dateString(cutoff);
      query['$datePrefix.lte'] = dateString(today);
    }
    final payload = await _get(path, query);

    final seenIds = <int>{};
    if (discoverIsTv == sourceIsTv) seenIds.add(sourceProviderId);
    final output = <CinematicTitleRecommendation>[];
    for (final row in _listOfMaps(payload['results'])) {
      final recommendation = CinematicTitleRecommendation.fromJson(
        row,
        isTv: discoverIsTv,
      );
      if (recommendation.providerId <= 0 ||
          recommendation.title.trim().isEmpty ||
          !seenIds.add(recommendation.providerId)) {
        continue;
      }
      output.add(recommendation);
      if (output.length >= limit) break;
    }
    return List<CinematicTitleRecommendation>.unmodifiable(output);
  }

  /// Pulls a bounded set of upcoming cinematic releases through the authenticated
  /// backend proxy. The calendar labels catalog dates as date-only whenever a
  /// reliable local air time is not supplied; it never fabricates an exact time.
  static Future<List<Map<String, dynamic>>> lookupUpcomingCalendarEvents({
    int movieLimit = 24,
    int tvLimit = 10,
    String? regionCode,
  }) async {
    if (!isConfigured) return const <Map<String, dynamic>>[];
    final now = DateTime.now();
    final cacheKey =
        '${(regionCode ?? '').trim().toUpperCase()}|$movieLimit|$tvLimit';
    final cached = _upcomingCalendarCache[cacheKey];
    final expiresAt = _upcomingCalendarCacheUntil[cacheKey];
    if (cached != null && expiresAt != null && now.isBefore(expiresAt)) {
      return List<Map<String, dynamic>>.unmodifiable(cached);
    }
    final active = _upcomingCalendarInFlight[cacheKey];
    if (active != null) return active;
    final request = _loadUpcomingCalendarEvents(
      movieLimit: movieLimit,
      tvLimit: tvLimit,
      regionCode: regionCode,
    );
    _upcomingCalendarInFlight[cacheKey] = request;
    try {
      final result = await request;
      _upcomingCalendarCache[cacheKey] = result;
      _upcomingCalendarCacheUntil[cacheKey] =
          now.add(const Duration(minutes: 20));
      return List<Map<String, dynamic>>.unmodifiable(result);
    } finally {
      _upcomingCalendarInFlight.remove(cacheKey);
    }
  }

  static Future<List<Map<String, dynamic>>> _loadUpcomingCalendarEvents({
    required int movieLimit,
    required int tvLimit,
    required String? regionCode,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 366));
    String? dateText(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.length < 10) return null;
      final date = DateTime.tryParse(raw.substring(0, 10));
      if (date == null) return null;
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    DateTime? localNoonForDate(dynamic value) {
      final normalized = dateText(value);
      if (normalized == null) return null;
      final parsed = DateTime.tryParse(normalized);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day, 12);
    }

    bool inWindow(DateTime? date, {bool allowRecentlyAired = false}) {
      if (date == null) return false;
      final start =
          allowRecentlyAired ? today.subtract(const Duration(days: 1)) : today;
      return !date.isBefore(start) && !date.isAfter(horizon);
    }

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    Map<String, dynamic>? moviePayload;
    Map<String, dynamic>? premierePayload;
    Map<String, dynamic>? onAirPayload;
    Map<String, dynamic>? nowPlayingPayload;
    final payloads = await Future.wait<
        Map<String, dynamic>?>(<Future<Map<String, dynamic>?>>[
      _get('/movie/upcoming', <String, String>{'page': '1'})
          .then((v) => v)
          .catchError((_) => <String, dynamic>{}),
      _get('/discover/tv', <String, String>{
        'page': '1',
        'sort_by': 'first_air_date.asc',
        'include_null_first_air_dates': 'false',
        'first_air_date.gte':
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        'first_air_date.lte':
            '${horizon.year.toString().padLeft(4, '0')}-${horizon.month.toString().padLeft(2, '0')}-${horizon.day.toString().padLeft(2, '0')}',
      }).then((v) => v).catchError((_) => <String, dynamic>{}),
      _get('/tv/on_the_air', <String, String>{'page': '1'})
          .then((v) => v)
          .catchError((_) => <String, dynamic>{}),
      _get('/movie/now_playing', <String, String>{'page': '1'})
          .then((v) => v)
          .catchError((_) => <String, dynamic>{}),
    ]);
    moviePayload = payloads[0];
    premierePayload = payloads[1];
    onAirPayload = payloads[2];
    nowPlayingPayload = payloads[3];

    for (final row in _listOfMaps(moviePayload?['results'])
        .take(movieLimit.clamp(1, 40).toInt())) {
      final releaseDate = dateText(row['release_date']);
      final target = localNoonForDate(releaseDate);
      final id = _toInt(row['id']);
      if (id == null || !inWindow(target) || releaseDate == null) continue;
      final eventId = 'tmdb-movie-$id-theatrical';
      if (!seenIds.add(eventId)) continue;
      results.add(<String, dynamic>{
        'id': eventId,
        'title': (row['title'] ?? row['original_title'] ?? 'Untitled movie')
            .toString(),
        'category': 'Movie',
        'milestone': 'Theatrical release',
        'scheduledAt': target!.toUtc().toIso8601String(),
        'dateOnly': true,
        'imageUrl': imageUrl(row['poster_path']?.toString(), size: 'w342'),
        'source': 'TMDB',
        'isManual': false,
        'note':
            'TMDB-reported theatrical date. Local cinema dates and times can differ by region.',
      });
    }

    for (final row in _listOfMaps(premierePayload?['results'])
        .take(tvLimit.clamp(1, 20).toInt())) {
      final releaseDate = dateText(row['first_air_date']);
      final target = localNoonForDate(releaseDate);
      final id = _toInt(row['id']);
      if (id == null || !inWindow(target) || releaseDate == null) continue;
      final eventId = 'tmdb-tv-$id-premiere';
      if (!seenIds.add(eventId)) continue;
      results.add(<String, dynamic>{
        'id': eventId,
        'title': (row['name'] ?? row['original_name'] ?? 'Untitled series')
            .toString(),
        'category': 'Show',
        'milestone': 'Series premiere',
        'scheduledAt': target!.toUtc().toIso8601String(),
        'dateOnly': true,
        'imageUrl': imageUrl(row['poster_path']?.toString(), size: 'w342'),
        'source': 'TMDB',
        'isManual': false,
        'note':
            'TMDB-reported first-air date. Streaming availability varies by country and provider.',
      });
    }

    final physicalCandidates = <Map<String, dynamic>>[];
    final candidateIds = <int>{};
    for (final raw in _listOfMaps(moviePayload?['results']).take(8)) {
      final id = _toInt(raw['id']);
      if (id != null && candidateIds.add(id)) physicalCandidates.add(raw);
    }
    for (final raw in _listOfMaps(nowPlayingPayload?['results']).take(10)) {
      final id = _toInt(raw['id']);
      final releasedAt = localNoonForDate(raw['release_date']);
      if (id == null || !candidateIds.add(id) || releasedAt == null) continue;
      if (releasedAt.isAfter(today.add(const Duration(days: 1))) ||
          releasedAt.isBefore(today.subtract(const Duration(days: 180)))) {
        continue;
      }
      physicalCandidates.add(raw);
    }
    final physicalFutures = physicalCandidates.take(14).map((movie) async {
      final id = _toInt(movie['id']);
      if (id == null) return <Map<String, dynamic>>[];
      try {
        final payload = await _get('/movie/$id/release_dates');
        final countryRows = _listOfMaps(payload['results']);
        final preferredRegion = (regionCode ?? '').trim().toUpperCase();
        final orderedCountries = <Map<String, dynamic>>[];
        if (preferredRegion.isNotEmpty) {
          orderedCountries.addAll(countryRows.where((row) =>
              (row['iso_3166_1']?.toString() ?? '').toUpperCase() ==
              preferredRegion));
        }
        orderedCountries.addAll(
            countryRows.where((row) => !orderedCountries.contains(row)));
        final physicalOptions = <Map<String, dynamic>>[];
        for (final country in orderedCountries) {
          final countryCode =
              (country['iso_3166_1'] ?? '').toString().trim().toUpperCase();
          for (final release in _listOfMaps(country['release_dates'])) {
            final kind = _toInt(release['type']);
            if (kind != 5) {
              continue; // TMDB release type 5 means physical media.
            }
            final date = localNoonForDate(release['release_date']);
            if (!inWindow(date) || date == null) continue;
            physicalOptions.add(<String, dynamic>{
              'date': date,
              'country': countryCode,
            });
          }
          // Prefer the device-locale region when it has a future physical date.
          if (physicalOptions.isNotEmpty && countryCode == preferredRegion) {
            break;
          }
        }
        if (physicalOptions.isEmpty) return <Map<String, dynamic>>[];
        physicalOptions.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        final option = physicalOptions.first;
        final date = option['date'] as DateTime;
        final country = option['country']?.toString() ?? '';
        final eventId = 'tmdb-movie-$id-physical-$country';
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': eventId,
            'title':
                (movie['title'] ?? movie['original_title'] ?? 'Untitled movie')
                    .toString(),
            'category': 'Movie',
            'milestone': 'Physical media release (format unspecified)',
            'scheduledAt': date.toUtc().toIso8601String(),
            'dateOnly': true,
            'imageUrl':
                imageUrl(movie['poster_path']?.toString(), size: 'w342'),
            'source': country.isEmpty ? 'TMDB' : 'TMDB · $country',
            'isManual': false,
            'note':
                'TMDB reports a physical release date${country.isEmpty ? '' : ' for $country'} but does not distinguish DVD, Blu-ray and 4K Ultra HD here. Add a format-specific date if known.',
          },
        ];
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }).toList(growable: false);
    final physicalResults = await Future.wait(physicalFutures);
    for (final group in physicalResults) {
      for (final event in group) {
        final eventId = event['id']?.toString() ?? '';
        if (eventId.isNotEmpty && seenIds.add(eventId)) results.add(event);
      }
    }

    final airingRows = _listOfMaps(onAirPayload?['results'])
        .take(tvLimit.clamp(1, 16).toInt())
        .toList(growable: false);
    final episodeFutures = airingRows.map((row) async {
      final id = _toInt(row['id']);
      if (id == null) return <Map<String, dynamic>>[];
      try {
        final details = await _get('/tv/$id');
        final episode = _asMap(details['next_episode_to_air']);
        if (episode.isEmpty) return <Map<String, dynamic>>[];
        final releaseDate = dateText(episode['air_date']);
        final target = localNoonForDate(releaseDate);
        if (!inWindow(target, allowRecentlyAired: true) ||
            releaseDate == null) {
          return <Map<String, dynamic>>[];
        }
        final seasonNumber =
            _toInt(episode['season_number'] ?? episode['seasonNumber']);
        final episodeNumber =
            _toInt(episode['episode_number'] ?? episode['episodeNumber']);
        final episodeName =
            _cleanNullable(episode['name']?.toString()) ?? 'New episode';
        final code = seasonNumber != null && episodeNumber != null
            ? 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}'
            : null;
        final title = (details['name'] ??
                details['original_name'] ??
                row['name'] ??
                'Series')
            .toString();
        final networks = _listOfMaps(details['networks'])
            .map((network) => _cleanNullable(network['name']?.toString()))
            .whereType<String>()
            .toSet()
            .toList(growable: false);
        final eventId =
            'tmdb-tv-$id-next-${episode['id'] ?? '${seasonNumber ?? 0}-${episodeNumber ?? 0}'}';
        final poster = imageUrl(
          episode['still_path']?.toString() ?? row['poster_path']?.toString(),
          size: 'w342',
        );
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': eventId,
            'title': '$title · ${code == null ? '' : '$code · '}$episodeName',
            'parentTitle': title,
            'category': 'Episode',
            'milestone': 'New episode · scheduled air date',
            'scheduledAt': target!.toUtc().toIso8601String(),
            'dateOnly': true,
            'imageUrl': poster,
            'source': 'TMDB',
            'isManual': false,
            'note': networks.isEmpty
                ? 'TMDB supplies the episode date but not an authoritative local airtime or streaming-ready time.'
                : 'Network: ${networks.join(', ')}. TMDB supplies the date, not an authoritative local airtime or streaming-ready time.',
          },
        ];
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }).toList(growable: false);
    final episodeResults = await Future.wait(episodeFutures);
    for (final group in episodeResults) {
      for (final event in group) {
        final eventId = event['id']?.toString() ?? '';
        if (eventId.isNotEmpty && seenIds.add(eventId)) results.add(event);
      }
    }

    results.sort((a, b) {
      final ad = DateTime.tryParse(a['scheduledAt']?.toString() ?? '') ??
          DateTime(2100);
      final bd = DateTime.tryParse(b['scheduledAt']?.toString() ?? '') ??
          DateTime(2100);
      return ad.compareTo(bd);
    });
    return results;
  }

  static int _videoTypePriority(String type) {
    switch (type.toLowerCase()) {
      case 'trailer':
        return 0;
      case 'teaser':
        return 1;
      case 'clip':
        return 2;
      case 'featurette':
        return 3;
      default:
        return 4;
    }
  }

  static Map<String, dynamic>? _findExactMatch(
    dynamic rawResults,
    String requestedTitle,
    bool isTv,
  ) {
    if (rawResults is! List) return null;
    final requested = _normalize(requestedTitle);
    for (final candidate in rawResults.whereType<Map>()) {
      final map = Map<String, dynamic>.from(candidate);
      final possibleTitles = isTv
          ? <dynamic>[map['name'], map['original_name']]
          : <dynamic>[map['title'], map['original_title']];
      if (possibleTitles.any((value) =>
          value != null && _normalize(value.toString()) == requested)) {
        return map;
      }
    }
    return null;
  }

  /// Normalize punctuation/spacing without discarding non-Latin letters.
  /// The previous ASCII-only expression normalized every Hangul/Japanese/
  /// Chinese title to an empty string, which could falsely match the first
  /// unrelated TMDB result for Korean and other original-script queries.
  static String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"), '');

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    dynamic listValue = value;
    if (value is Map && value['results'] is List) {
      listValue = value['results'];
    }
    if (listValue is! List) return <Map<String, dynamic>>[];
    return listValue
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static List<String> _uniqueStrings(Iterable<String?> values) {
    final output = <String>[];
    for (final raw in values) {
      final value = raw?.trim() ?? '';
      if (value.isNotEmpty && !output.contains(value)) output.add(value);
    }
    return output;
  }

  static String _countryName(String value) => formatCountryName(value);

  static String? _cleanNullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _positiveIntOrNull(dynamic value) {
    final parsed = _toInt(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _firstPositiveInt(dynamic value) {
    if (value is List) {
      for (final candidate in value) {
        final parsed = _positiveIntOrNull(candidate);
        if (parsed != null) return parsed;
      }
    }
    return _positiveIntOrNull(value);
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) {
    return AppController.instance.backendApi.getTmdbMetadata(
      path,
      <String, String>{'language': 'en-US', ...?query},
    );
  }
}

/// A mood/category offered by TMDB-backed recommendations.
class CinematicRecommendationMood {
  const CinematicRecommendationMood({
    required this.key,
    required this.label,
    required this.movieGenreId,
    required this.tvGenreId,
    this.forceMovie = false,
  });

  final String key;
  final String label;
  final int movieGenreId;
  final int tvGenreId;
  final bool forceMovie;

  static const List<CinematicRecommendationMood> all = [
    CinematicRecommendationMood(
      key: 'adventurous',
      label: 'adventurous',
      movieGenreId: 12,
      tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'fantastical',
      label: 'fantastical',
      movieGenreId: 14,
      tvGenreId: 10765,
    ),
    CinematicRecommendationMood(
      key: 'animated',
      label: 'animated',
      movieGenreId: 16,
      tvGenreId: 16,
    ),
    CinematicRecommendationMood(
      key: 'dramatic',
      label: 'dramatic',
      movieGenreId: 18,
      tvGenreId: 18,
    ),
    CinematicRecommendationMood(
      key: 'terrifying',
      label: 'terrifying',
      movieGenreId: 27,
      tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'action-packed',
      label: 'action-packed',
      movieGenreId: 28,
      tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'funny',
      label: 'funny',
      movieGenreId: 35,
      tvGenreId: 35,
    ),
    CinematicRecommendationMood(
      key: 'historical',
      label: 'historical',
      movieGenreId: 36,
      tvGenreId: 10768,
    ),
    CinematicRecommendationMood(
      key: 'rugged',
      label: 'rugged',
      movieGenreId: 37,
      tvGenreId: 37,
    ),
    CinematicRecommendationMood(
      key: 'suspenseful',
      label: 'suspenseful',
      movieGenreId: 53,
      tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'gritty',
      label: 'gritty',
      movieGenreId: 80,
      tvGenreId: 80,
    ),
    CinematicRecommendationMood(
      key: 'thought-provoking',
      label: 'thought-provoking',
      movieGenreId: 99,
      tvGenreId: 99,
    ),
    CinematicRecommendationMood(
      key: 'out-of-this-world',
      label: 'out of this world',
      movieGenreId: 878,
      tvGenreId: 10765,
    ),
    CinematicRecommendationMood(
      key: 'mysterious',
      label: 'mysterious',
      movieGenreId: 9648,
      tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'musical',
      label: 'musical',
      movieGenreId: 10402,
      tvGenreId: 10402,
    ),
    CinematicRecommendationMood(
      key: 'romantic',
      label: 'romantic',
      movieGenreId: 10749,
      tvGenreId: 18,
    ),
    CinematicRecommendationMood(
      key: 'family-friendly',
      label: 'family-friendly',
      movieGenreId: 10751,
      tvGenreId: 10762,
    ),
    CinematicRecommendationMood(
      key: 'kid-friendly',
      label: 'kid-friendly',
      movieGenreId: 10751,
      tvGenreId: 10762,
    ),
    CinematicRecommendationMood(
      key: 'thrilling',
      label: 'thrilling',
      movieGenreId: 53,
      tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'current',
      label: 'current',
      movieGenreId: 0,
      tvGenreId: 0,
    ),
    CinematicRecommendationMood(
      key: 'unscripted',
      label: 'unscripted',
      movieGenreId: 99,
      tvGenreId: 10764,
    ),
    CinematicRecommendationMood(
      key: 'imaginative',
      label: 'imaginative',
      movieGenreId: 14,
      tvGenreId: 10765,
    ),
    CinematicRecommendationMood(
      key: 'scandalous',
      label: 'scandalous',
      movieGenreId: 18,
      tvGenreId: 10764,
    ),
    CinematicRecommendationMood(
      key: 'candid',
      label: 'candid',
      movieGenreId: 99,
      tvGenreId: 10764,
    ),
    CinematicRecommendationMood(
      key: 'politically-charged',
      label: 'politically charged',
      movieGenreId: 99,
      tvGenreId: 10768,
    ),
    CinematicRecommendationMood(
      key: 'heroic',
      label: 'heroic',
      movieGenreId: 12,
      tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'made-for-tv',
      label: 'made-for-TV',
      movieGenreId: 10770,
      tvGenreId: 10770,
      forceMovie: true,
    ),
  ];

  static CinematicRecommendationMood? byKey(String key) {
    for (final mood in all) {
      if (mood.key == key) return mood;
    }
    return null;
  }
}

class CinematicTitleMetadata {
  const CinematicTitleMetadata({
    required this.providerId,
    this.imdbId,
    required this.title,
    required this.isTv,
    this.countryOfOrigin,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    this.lastAirDate,
    required this.originalTitle,
    required this.tagline,
    required this.homepage,
    required this.status,
    required this.originalLanguage,
    required this.voteAverage,
    required this.voteCount,
    required this.budget,
    required this.revenue,
    required this.runtimeMinutes,
    required this.genres,
    required this.keywords,
    required this.posterPaths,
    required this.backdropPaths,
    required this.logoPaths,
    required this.videos,
    required this.reviews,
    required this.cast,
    required this.characters,
    required this.castCredits,
    required this.crewCredits,
    required this.seasons,
    required this.directors,
    required this.writers,
    required this.music,
  });

  final int providerId;

  /// IMDb title identifier used for optional OMDb rating lookup.
  final String? imdbId;
  final String title;
  final bool isTv;
  final String? countryOfOrigin;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;

  /// Final reported first-air date for a series, if TMDB provides one.
  final String? lastAirDate;
  final String? originalTitle;
  final String? tagline;
  final String? homepage;
  final String? status;
  final String? originalLanguage;
  final double? voteAverage;
  final int? voteCount;
  final int? budget;
  final int? revenue;
  final int? runtimeMinutes;
  final List<String> genres;
  final List<String> keywords;
  final List<String> posterPaths;
  final List<String> backdropPaths;

  /// TMDB transparent title-logo image paths, with the best language match first.
  final List<String> logoPaths;
  final List<CinematicTitleVideo> videos;
  final List<CinematicTitleReview> reviews;
  final List<String> cast;
  final List<String> characters;

  /// Sourced cast credits with roles and portrait paths, suitable for X-Ray.
  final List<CinematicCastCredit> castCredits;

  /// Sourced production credits, including producers and screenwriters.
  final List<CinematicCrewCredit> crewCredits;

  /// Season summaries from TMDB; per-season episode lists are fetched lazily.
  final List<Map<String, dynamic>> seasons;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;

  String? get posterUrl => CinematicTitleMetadataService.imageUrl(posterPath);
  String? get backdropUrl => CinematicTitleMetadataService.imageUrl(
        backdropPath,
        size: 'w780',
      );

  String? get logoUrl => logoPaths.isEmpty
      ? null
      : CinematicTitleMetadataService.imageUrl(logoPaths.first,
          size: 'original');
}

/// A verified cast credit returned by TMDB for one exact movie or TV title.
class CinematicCastCredit {
  const CinematicCastCredit({
    required this.personId,
    required this.name,
    required this.character,
    required this.profilePath,
    required this.order,
  });

  final int? personId;
  final String name;
  final String character;
  final String? profilePath;
  final int order;

  factory CinematicCastCredit.fromJson(Map<String, dynamic> row) {
    final personIdValue = row['id'];
    final orderValue = row['order'];
    return CinematicCastCredit(
      personId: personIdValue is int
          ? personIdValue
          : int.tryParse(personIdValue?.toString() ?? ''),
      name: row['name']?.toString().trim() ?? '',
      character: row['character']?.toString().trim() ?? '',
      profilePath: row['profile_path']?.toString(),
      order: orderValue is int
          ? orderValue
          : int.tryParse(orderValue?.toString() ?? '') ?? 9999,
    );
  }
}

/// A sourced director, screenwriter, producer or other crew credit for X-Ray.
class CinematicCrewCredit {
  const CinematicCrewCredit({
    required this.personId,
    required this.name,
    required this.job,
    required this.department,
    required this.profilePath,
  });

  final int? personId;
  final String name;
  final String job;
  final String department;
  final String? profilePath;

  factory CinematicCrewCredit.fromJson(Map<String, dynamic> row) {
    final rawId = row['id'];
    final job = row['job']?.toString().trim() ?? '';
    return CinematicCrewCredit(
      personId: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      name: row['name']?.toString().trim() ?? '',
      job: job.isEmpty
          ? (row['known_for_department']?.toString().trim() ?? 'Crew')
          : job,
      department: row['department']?.toString().trim() ?? '',
      profilePath: row['profile_path']?.toString(),
    );
  }
}

/// A TMDB-powered movie or television recommendation.
class CinematicTitleRecommendation {
  const CinematicTitleRecommendation({
    required this.providerId,
    required this.title,
    required this.isTv,
    this.countryOfOrigin,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
  });

  final int providerId;
  final String title;
  final bool isTv;
  final String? countryOfOrigin;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double? voteAverage;
  final int? voteCount;

  int? get releaseYear {
    final value = releaseDate?.trim() ?? '';
    if (value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }

  String get mediaTypeLabel => isTv ? 'TV show' : 'Movie';

  String? get posterUrl => CinematicTitleMetadataService.imageUrl(
        posterPath,
        size: 'w342',
      );

  String? get backdropUrl => CinematicTitleMetadataService.imageUrl(
        backdropPath,
        size: 'w780',
      );

  factory CinematicTitleRecommendation.fromJson(
    Map<String, dynamic> json, {
    required bool isTv,
  }) {
    final rawTitle = isTv
        ? (json['name'] ?? json['original_name'])
        : (json['title'] ?? json['original_title']);
    final rawDate = isTv ? json['first_air_date'] : json['release_date'];
    final rawId = json['id'];
    final rawVoteAverage = json['vote_average'];
    final rawVoteCount = json['vote_count'];
    return CinematicTitleRecommendation(
      providerId:
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      title: rawTitle?.toString().trim() ?? '',
      isTv: isTv,
      overview: json['overview']?.toString().trim() ?? '',
      posterPath: _reviewText(json['poster_path']),
      backdropPath: _reviewText(json['backdrop_path']),
      releaseDate: _reviewText(rawDate),
      voteAverage: rawVoteAverage is num
          ? rawVoteAverage.toDouble()
          : double.tryParse(rawVoteAverage?.toString() ?? ''),
      voteCount: rawVoteCount is int
          ? rawVoteCount
          : int.tryParse(rawVoteCount?.toString() ?? ''),
    );
  }
}

class CinematicTitleVideo {
  const CinematicTitleVideo({
    required this.name,
    required this.key,
    required this.site,
    required this.type,
    required this.official,
    required this.publishedAt,
  });

  final String name;
  final String key;
  final String site;
  final String type;
  final bool official;
  final String? publishedAt;

  String? get url {
    final normalizedSite = site.toLowerCase();
    if (normalizedSite == 'youtube') {
      return 'https://www.youtube.com/watch?v=$key';
    }
    if (normalizedSite == 'vimeo') {
      return 'https://vimeo.com/$key';
    }
    return null;
  }

  factory CinematicTitleVideo.fromJson(Map<String, dynamic> json) {
    return CinematicTitleVideo(
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Untitled video',
      key: json['key']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Video',
      official: json['official'] == true,
      publishedAt: _reviewText(json['published_at']),
    );
  }
}

class CinematicTitleReview {
  const CinematicTitleReview({
    this.id,
    required this.author,
    required this.content,
    required this.rating,
    required this.createdAt,
    required this.url,
  });

  /// Stable TMDB review id; a caller may fall back to author/date/content.
  final String? id;
  final String author;
  final String content;
  final double? rating;
  final String? createdAt;
  final String? url;

  factory CinematicTitleReview.fromJson(Map<String, dynamic> json) {
    // Keep the decoded JSON dynamic values separate from their parsed form.
    // Some API responses omit author_details or send it as null/non-map data.
    final rawAuthorDetails = json['author_details'];
    final Map<String, dynamic> authorDetails = <String, dynamic>{};
    if (rawAuthorDetails is Map) {
      for (final entry in rawAuthorDetails.entries) {
        authorDetails[entry.key.toString()] = entry.value;
      }
    }

    var authorName = 'TMDB user';
    for (final candidate in <dynamic>[
      authorDetails['name'],
      json['author'],
      authorDetails['username'],
    ]) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        authorName = value;
        break;
      }
    }

    final rawRating = authorDetails['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '');
    return CinematicTitleReview(
      id: _reviewText(json['id']),
      author: authorName,
      content: json['content']?.toString() ?? '',
      rating: rating,
      createdAt: _reviewText(json['created_at']),
      url: _reviewText(json['url']),
    );
  }
}

class CinematicTitleReviewPage {
  const CinematicTitleReviewPage({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    required this.reviews,
  });

  final int page;
  final int totalPages;
  final int totalResults;
  final List<CinematicTitleReview> reviews;

  bool get hasMore => page < totalPages;
}

String? _reviewText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
