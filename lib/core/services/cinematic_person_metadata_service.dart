import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';

/// TMDB-backed person identities, portraits, biographies, and combined credits.
/// Configure TMDB_API_KEY in the project-root .env file, or use --dart-define as a fallback.
class CinematicPersonMetadataService {
  CinematicPersonMetadataService._();

  static String get _apiKey => AppEnv.tmdbApiKey;
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';
  static final Map<String, Future<CinematicPersonSummary?>> _summaryCache =
      <String, Future<CinematicPersonSummary?>>{};
  static final Map<String, Future<CinematicPersonMetadata?>> _profileCache =
      <String, Future<CinematicPersonMetadata?>>{};

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static String? imageUrl(String? imagePath, {String size = 'w342'}) {
    final path = imagePath?.trim() ?? '';
    if (path.isEmpty || !path.startsWith('/')) return null;
    return '$_imageBaseUrl/$size$path';
  }

  /// Searches by name but only accepts an exact normalized match. This avoids
  /// attaching another person with a similar name to a local credit.
  static Future<CinematicPersonSummary?> lookupPersonSummary(String name) {
    final normalized = _normalize(name);
    if (!isConfigured || normalized.isEmpty) {
      return Future<CinematicPersonSummary?>.value(null);
    }
    return _summaryCache.putIfAbsent(normalized, () => _searchPerson(name));
  }

  static Future<CinematicPersonMetadata?> lookupPersonProfile(String name) {
    final normalized = _normalize(name);
    if (!isConfigured || normalized.isEmpty) {
      return Future<CinematicPersonMetadata?>.value(null);
    }
    return _profileCache.putIfAbsent(
      normalized,
      () => _loadProfile(name),
    );
  }

  static Future<CinematicPersonSummary?> _searchPerson(String name) async {
    final response = await _get('/search/person', <String, String>{
      'query': name.trim(),
      'include_adult': 'false',
      'page': '1',
      'language': 'en-US',
    });
    final results = response['results'];
    if (results is! List) return null;
    final requested = _normalize(name);
    for (final candidate in results.whereType<Map>()) {
      final row = Map<String, dynamic>.from(candidate);
      final candidateName = row['name']?.toString().trim() ?? '';
      if (candidateName.isEmpty || _normalize(candidateName) != requested) {
        continue;
      }
      final id = _asInt(row['id']);
      if (id == null) continue;
      return CinematicPersonSummary(
        id: id,
        name: candidateName,
        profilePath: row['profile_path']?.toString(),
        knownForDepartment: row['known_for_department']?.toString(),
      );
    }
    return null;
  }

  static Future<CinematicPersonMetadata?> _loadProfile(String name) async {
    final summary = await lookupPersonSummary(name);
    if (summary == null) return null;

    final detailFuture = _get('/person/${summary.id}', <String, String>{
      'language': 'en-US',
    });
    final creditsFuture = _get(
      '/person/${summary.id}/combined_credits',
      <String, String>{'language': 'en-US'},
    );
    final detailResults = await Future.wait<Map<String, dynamic>>(
      <Future<Map<String, dynamic>>>[detailFuture, creditsFuture],
    );
    final details = detailResults[0];
    final creditsData = detailResults[1];

    final worksByKey = <String, CinematicPersonCredit>{};
    void addCredits(dynamic raw, {required bool isCast}) {
      if (raw is! List) return;
      for (final value in raw.whereType<Map>()) {
        final row = Map<String, dynamic>.from(value);
        final id = _asInt(row['id']);
        final mediaType = row['media_type']?.toString().toLowerCase() ?? '';
        if (id == null || (mediaType != 'movie' && mediaType != 'tv')) continue;
        final title = (mediaType == 'tv'
                ? row['name'] ?? row['original_name']
                : row['title'] ?? row['original_title'])
            ?.toString()
            .trim() ?? '';
        if (title.isEmpty) continue;
        final date = (mediaType == 'tv'
                ? row['first_air_date']
                : row['release_date'])
            ?.toString();
        final key = '$mediaType:$id';
        final job = row['job']?.toString().trim() ?? '';
        final character = row['character']?.toString().trim() ?? '';
        final role = isCast
            ? (character.isEmpty ? 'Cast' : character)
            : (job.isNotEmpty ? job : (row['department']?.toString() ?? 'Crew'));
        final previous = worksByKey[key];
        if (previous != null) {
          if (previous.roleLabel == 'Cast' && role != 'Cast') {
            worksByKey[key] = previous.copyWith(
              roleLabel: role,
              department: row['department']?.toString(),
            );
          }
          continue;
        }
        worksByKey[key] = CinematicPersonCredit(
          id: id,
          title: title,
          mediaType: mediaType,
          releaseDate: date?.isNotEmpty == true ? date : null,
          posterPath: row['poster_path']?.toString(),
          roleLabel: role,
          department: row['department']?.toString(),
          overview: row['overview']?.toString() ?? '',
        );
      }
    }

    addCredits(creditsData['cast'], isCast: true);
    addCredits(creditsData['crew'], isCast: false);
    final filmography = worksByKey.values.toList(growable: false)
      ..sort((a, b) {
        final aYear = a.releaseYear;
        final bYear = b.releaseYear;
        if (aYear != null && bYear != null && aYear != bYear) {
          return bYear.compareTo(aYear);
        }
        if (aYear != null && bYear == null) return -1;
        if (aYear == null && bYear != null) return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    final alsoKnownAs = details['also_known_as'] is List
        ? (details['also_known_as'] as List)
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return CinematicPersonMetadata(
      person: CinematicPersonSummary(
        id: summary.id,
        name: details['name']?.toString().trim().isNotEmpty == true
            ? details['name'].toString().trim()
            : summary.name,
        profilePath: details['profile_path']?.toString() ?? summary.profilePath,
        knownForDepartment: details['known_for_department']?.toString() ??
            summary.knownForDepartment,
      ),
      biography: details['biography']?.toString().trim() ?? '',
      birthday: details['birthday']?.toString(),
      deathday: details['deathday']?.toString(),
      placeOfBirth: details['place_of_birth']?.toString(),
      alsoKnownAs: alsoKnownAs,
      filmography: filmography,
    );
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
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw Exception('TMDB returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('TMDB returned an unexpected response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class CinematicPersonSummary {
  const CinematicPersonSummary({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.knownForDepartment,
  });

  final int id;
  final String name;
  final String? profilePath;
  final String? knownForDepartment;
}

class CinematicPersonMetadata {
  const CinematicPersonMetadata({
    required this.person,
    required this.biography,
    required this.birthday,
    required this.deathday,
    required this.placeOfBirth,
    required this.alsoKnownAs,
    required this.filmography,
  });

  final CinematicPersonSummary person;
  final String biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final List<String> alsoKnownAs;
  final List<CinematicPersonCredit> filmography;
}

class CinematicPersonCredit {
  const CinematicPersonCredit({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.releaseDate,
    required this.posterPath,
    required this.roleLabel,
    required this.department,
    required this.overview,
  });

  final int id;
  final String title;
  final String mediaType;
  final String? releaseDate;
  final String? posterPath;
  final String roleLabel;
  final String? department;
  final String overview;

  int? get releaseYear {
    final date = releaseDate?.trim() ?? '';
    if (date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  CinematicPersonCredit copyWith({String? roleLabel, String? department}) =>
      CinematicPersonCredit(
        id: id,
        title: title,
        mediaType: mediaType,
        releaseDate: releaseDate,
        posterPath: posterPath,
        roleLabel: roleLabel ?? this.roleLabel,
        department: department ?? this.department,
        overview: overview,
      );
}
