import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// Live title metadata and credits from TMDB.
///
/// Uses `append_to_response` so the detail request can include credits, videos,
/// keywords, reviews and all available posters/backdrops in one API call.
class CinematicTitleMetadataService {
  CinematicTitleMetadataService._();

  static String get _apiKey => AppEnv.tmdbApiKey;
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';
  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Turns a TMDB image path into a publicly loadable image URL.
  static String? imageUrl(String? path, {String size = 'w500'}) {
    final cleaned = path?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('https://') || cleaned.startsWith('http://')) {
      return cleaned;
    }
    return '$imageBaseUrl/$size/${cleaned.startsWith('/') ? cleaned.substring(1) : cleaned}';
  }

  /// Lightweight overview lookup for Home hero banners. Unlike [lookupTitle],
  /// this requests only search results and basic title details instead of also
  /// loading credits, images, videos, keywords, and reviews.
  static Future<String?> lookupOverview({
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

    // A catalog year can be missing or stale. Retry without it while still
    // requiring an exact normalized title match to prevent mismatched synopses.
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

    final details = await _get(isTv ? '/tv/$id' : '/movie/$id');
    return _cleanNullable(details['overview']);
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
      'append_to_response': 'credits,videos,keywords,reviews,images',
      'include_image_language': 'en,null',
      'language': 'en-US',
    });

    final credits = _asMap(details['credits']);
    final castRows = _listOfMaps(credits['cast']);
    final crewRows = _listOfMaps(credits['crew']);

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

    final actualTitle = (isTv
            ? details['name'] ?? details['original_name']
            : details['title'] ?? details['original_title'])
        ?.toString()
        .trim();
    final releaseDate = (isTv
            ? details['first_air_date']
            : details['release_date'])
        ?.toString();
    final imagePayload = _asMap(details['images']);

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

    return CinematicTitleMetadata(
      providerId: id,
      title: actualTitle?.isNotEmpty == true ? actualTitle! : cleanTitle,
      isTv: isTv,
      overview: details['overview']?.toString() ?? '',
      posterPath: _cleanNullable(details['poster_path']),
      backdropPath: _cleanNullable(details['backdrop_path']),
      releaseDate: releaseDate?.isNotEmpty == true ? releaseDate : null,
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
      videos: videos,
      reviews: reviews,
      cast: cast,
      characters: characters,
      directors: directors,
      writers: writers,
      music: music,
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
    final payload = await _get(path, <String, String>{
      'page': '1',
      'include_adult': 'false',
      'sort_by': 'popularity.desc',
      'vote_count.gte': '10',
      'with_genres': genreId.toString(),
    });

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

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

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
  ]) async {
    final params = <String, String>{
      'api_key': _apiKey,
      'language': 'en-US',
      ...?query,
    };
    final response = await http
        .get(Uri.parse('$_baseUrl$path').replace(queryParameters: params))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('TMDB returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('TMDB returned an unexpected response.');
    }
    return Map<String, dynamic>.from(decoded);
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
      key: 'adventurous', label: 'adventurous', movieGenreId: 12, tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'fantastical', label: 'fantastical', movieGenreId: 14, tvGenreId: 10765,
    ),
    CinematicRecommendationMood(
      key: 'animated', label: 'animated', movieGenreId: 16, tvGenreId: 16,
    ),
    CinematicRecommendationMood(
      key: 'dramatic', label: 'dramatic', movieGenreId: 18, tvGenreId: 18,
    ),
    CinematicRecommendationMood(
      key: 'terrifying', label: 'terrifying', movieGenreId: 27, tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'action-packed', label: 'action-packed', movieGenreId: 28, tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'funny', label: 'funny', movieGenreId: 35, tvGenreId: 35,
    ),
    CinematicRecommendationMood(
      key: 'historical', label: 'historical', movieGenreId: 36, tvGenreId: 10768,
    ),
    CinematicRecommendationMood(
      key: 'rugged', label: 'rugged', movieGenreId: 37, tvGenreId: 37,
    ),
    CinematicRecommendationMood(
      key: 'suspenseful', label: 'suspenseful', movieGenreId: 53, tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'gritty', label: 'gritty', movieGenreId: 80, tvGenreId: 80,
    ),
    CinematicRecommendationMood(
      key: 'thought-provoking', label: 'thought-provoking', movieGenreId: 99, tvGenreId: 99,
    ),
    CinematicRecommendationMood(
      key: 'out-of-this-world', label: 'out of this world', movieGenreId: 878, tvGenreId: 10765,
    ),
    CinematicRecommendationMood(
      key: 'mysterious', label: 'mysterious', movieGenreId: 9648, tvGenreId: 9648,
    ),
    CinematicRecommendationMood(
      key: 'musical', label: 'musical', movieGenreId: 10402, tvGenreId: 10402,
    ),
    CinematicRecommendationMood(
      key: 'romantic', label: 'romantic', movieGenreId: 10749, tvGenreId: 18,
    ),
    CinematicRecommendationMood(
      key: 'family-friendly', label: 'family-friendly', movieGenreId: 10751, tvGenreId: 10762,
    ),
    CinematicRecommendationMood(
      key: 'heroic', label: 'heroic', movieGenreId: 12, tvGenreId: 10759,
    ),
    CinematicRecommendationMood(
      key: 'made-for-tv', label: 'made-for-TV', movieGenreId: 10770, tvGenreId: 10770, forceMovie: true,
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
    required this.title,
    required this.isTv,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
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
    required this.videos,
    required this.reviews,
    required this.cast,
    required this.characters,
    required this.directors,
    required this.writers,
    required this.music,
  });

  final int providerId;
  final String title;
  final bool isTv;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
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
  final List<CinematicTitleVideo> videos;
  final List<CinematicTitleReview> reviews;
  final List<String> cast;
  final List<String> characters;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;

  String? get posterUrl => CinematicTitleMetadataService.imageUrl(posterPath);
  String? get backdropUrl => CinematicTitleMetadataService.imageUrl(
        backdropPath,
        size: 'w780',
      );
}

/// A TMDB-powered movie or television recommendation.
class CinematicTitleRecommendation {
  const CinematicTitleRecommendation({
    required this.providerId,
    required this.title,
    required this.isTv,
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
      providerId: rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '') ?? 0,
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
    if (normalizedSite == 'youtube') return 'https://www.youtube.com/watch?v=$key';
    if (normalizedSite == 'vimeo') return 'https://vimeo.com/$key';
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
    required this.author,
    required this.content,
    required this.rating,
    required this.createdAt,
    required this.url,
  });

  final String author;
  final String content;
  final double? rating;
  final String? createdAt;
  final String? url;

  factory CinematicTitleReview.fromJson(Map<String, dynamic> json) {
    final authorDetails = json['author_details'] is Map
        ? Map<String, dynamic>.from(json['author_details'] as Map)
        : <String, dynamic>{};
    final authorName = (authorDetails['name'] ?? json['author'] ??
            authorDetails['username'] ?? 'TMDB user')
        .toString()
        .trim();
    final rawRating = authorDetails['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '');
    return CinematicTitleReview(
      author: authorName.isEmpty ? 'TMDB user' : authorName,
      content: json['content']?.toString() ?? '',
      rating: rating,
      createdAt: _reviewText(json['created_at']),
      url: _reviewText(json['url']),
    );
  }
}

String? _reviewText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
