// FILE: Backend/services/sports_service.dart.
// Purpose: Implements the sports service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Sports data is divided into two distinct concerns:
//
// 1. Scoreboard metadata:
//    - scores
//    - teams
//    - status
//    - clocks
//    - schedules
//
// 2. Authorized broadcast metadata:
//    - provider
//    - authorization
//    - authentic/original status
//    - playable stream URL
//
// A public scoreboard feed never grants streaming rights.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/sports.dart';

class SportsService {
  static const Duration _requestTimeout = Duration(seconds: 15);

  static const int minimumUpcomingDays = 1;
  static const int maximumUpcomingDays = 14;

  static const int _maximumResponseBytes = 5 * 1024 * 1024;

  static const List<Map<String, String>> _espnFeeds = [
    {
      'sport': 'American Football',
      'country': 'United States',
      'path': 'football/nfl',
    },
    {
      'sport': 'Basketball',
      'country': 'United States',
      'path': 'basketball/nba',
    },
    {
      'sport': 'Hockey',
      'country': 'United States',
      'path': 'hockey/nhl',
    },
    {
      'sport': 'Baseball',
      'country': 'United States',
      'path': 'baseball/mlb',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/eng.1',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/esp.1',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/ger.1',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/ita.1',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/fra.1',
    },
    {
      'sport': 'Soccer',
      'country': 'Mexico',
      'path': 'soccer/mex.1',
    },
    {
      'sport': 'Soccer',
      'country': 'United States',
      'path': 'soccer/usa.1',
    },
    {
      'sport': 'Soccer',
      'country': 'International',
      'path': 'soccer/uefa.champions',
    },
  ];

  const SportsService();

  // ==========================================================
  // LIVE GAMES
  // ==========================================================

  Future<List<SportsGame>> liveGames({
    String? sport,
    String? country,
  }) async {
    final normalizedSport = _normalizeFilter(sport);
    final normalizedCountry = _normalizeFilter(country);

    final results = <SportsGame>[];

    // A configured rights feed takes precedence because only a configured
    // rights provider can provide authorized/original playable streams.
    final configured = Platform.environment['SPORTS_RIGHTS_FEED_URL']?.trim();

    if (configured != null && configured.isNotEmpty) {
      final uri = _safeConfiguredFeedUri(configured);

      if (uri != null) {
        try {
          results.addAll(
            await _loadConfiguredRightsFeed(uri),
          );
        } catch (_) {
          // Fall back to scoreboard metadata.
        }
      }
    }

    // Public scoreboard fallback.
    if (results.isEmpty) {
      for (final feed in _espnFeeds) {
        if (!_feedMatches(
          feed,
          sport: normalizedSport,
          country: normalizedCountry,
        )) {
          continue;
        }

        try {
          results.addAll(
            await _loadScoreboard(feed),
          );
        } catch (_) {
          // One unavailable league must not prevent other sports from loading.
        }
      }
    }

    final filtered = <SportsGame>[];
    final seen = <String>{};

    for (final game in results) {
      if (!_gameMatches(
        game,
        sport: normalizedSport,
        country: normalizedCountry,
      )) {
        continue;
      }

      final id = game.id.trim();

      if (id.isEmpty || !seen.add(id)) {
        continue;
      }

      filtered.add(game);
    }

    filtered.sort(_compareGames);

    return List<SportsGame>.unmodifiable(filtered);
  }

  // ==========================================================
  // UPCOMING GAMES
  // ==========================================================

  Future<List<SportsGame>> upcomingGames({
    String? sport,
    String? country,
    int days = 7,
  }) async {
    final normalizedSport = _normalizeFilter(sport);
    final normalizedCountry = _normalizeFilter(country);
    final effectiveDays = _validateDays(days);

    final results = <SportsGame>[];
    final now = DateTime.now();

    for (var offset = 0; offset <= effectiveDays; offset++) {
      final date = now.add(
        Duration(days: offset),
      );

      final dateCode =
          '${date.year.toString().padLeft(4, '0')}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';

      for (final feed in _espnFeeds) {
        if (!_feedMatches(
          feed,
          sport: normalizedSport,
          country: normalizedCountry,
        )) {
          continue;
        }

        try {
          final dayGames = await _loadScoreboard(
            feed,
            date: dateCode,
            upcomingOnly: true,
          );

          for (final game in dayGames) {
            if (!_gameMatches(
              game,
              sport: normalizedSport,
              country: normalizedCountry,
            )) {
              continue;
            }

            final start = DateTime.tryParse(
              game.startTime ?? '',
            );

            if (start != null && !start.isAfter(now)) {
              continue;
            }

            results.add(game);
          }
        } catch (_) {
          // One unavailable league/date must not prevent other events.
        }
      }
    }

    final output = <SportsGame>[];
    final seen = <String>{};

    for (final game in results) {
      if (game.id.trim().isEmpty || !seen.add(game.id)) {
        continue;
      }

      output.add(game);
    }

    output.sort(_compareGames);

    return List<SportsGame>.unmodifiable(output);
  }

  // ==========================================================
  // TEAMS
  // ==========================================================

  Future<List<Map<String, dynamic>>> availableTeams() async {
    final loaded = await Future.wait(
      _espnFeeds.map(
        (feed) async {
          try {
            final teams = await _loadTeams(feed);

            return <String, dynamic>{
              'league': _leagueLabel(feed),
              'leagueKey': feed['path']!.split('/').last,
              'sport': feed['sport'],
              'country': feed['country'],
              'teams': teams,
            };
          } catch (_) {
            return null;
          }
        },
      ),
    );

    return List<Map<String, dynamic>>.unmodifiable(
      loaded.whereType<Map<String, dynamic>>(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadTeams(
    Map<String, String> feed,
  ) async {
    final path = feed['path'];

    if (path == null || path.trim().isEmpty) {
      throw const FormatException('Invalid sports feed path.');
    }

    final uri = Uri.parse(
      'https://site.api.espn.com/apis/site/v2/sports/$path/teams',
    );

    final body = await _getJsonText(uri);

    final data = jsonDecode(body);

    if (data is! Map) {
      return const [];
    }

    final sports = data['sports'];

    if (sports is! List) {
      return const [];
    }

    final output = <Map<String, dynamic>>[];

    for (final sport in sports) {
      if (sport is! Map) {
        continue;
      }

      final leagues = sport['leagues'];

      if (leagues is! List) {
        continue;
      }

      for (final league in leagues) {
        if (league is! Map) {
          continue;
        }

        final teams = league['teams'];

        if (teams is! List) {
          continue;
        }

        for (final wrapper in teams) {
          Map<String, dynamic>? team;

          if (wrapper is Map && wrapper['team'] is Map) {
            team = Map<String, dynamic>.from(
              wrapper['team'] as Map,
            );
          } else if (wrapper is Map) {
            team = Map<String, dynamic>.from(wrapper);
          }

          if (team == null) {
            continue;
          }

          final name =
              team['displayName']?.toString() ??
              team['name']?.toString();

          if (name == null || name.trim().isEmpty) {
            continue;
          }

          final normalizedName = name.trim();

          output.add({
            'id': team['id']?.toString() ?? normalizedName,
            'name': normalizedName,
            'shortName':
                team['shortDisplayName']?.toString() ??
                team['name']?.toString() ??
                normalizedName,
            'abbreviation':
                team['abbreviation']?.toString() ?? '',
            'logo': _teamLogo(team),
          });
        }
      }
    }

    final seen = <String>{};

    output.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
    );

    return List<Map<String, dynamic>>.unmodifiable(
      output.where(
        (team) => seen.add(
          (team['name'] as String).toLowerCase(),
        ),
      ),
    );
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final logos = team['logos'];

    if (logos is! List) {
      return null;
    }

    for (final logo in logos.whereType<Map>()) {
      final href = logo['href']?.toString().trim();

      if (href == null || href.isEmpty) {
        continue;
      }

      final uri = Uri.tryParse(href);

      if (uri != null &&
          uri.scheme.toLowerCase() == 'https' &&
          uri.host.isNotEmpty) {
        return href;
      }
    }

    return null;
  }

  // ==========================================================
  // CONFIGURED RIGHTS FEED
  // ==========================================================

  Future<List<SportsGame>> _loadConfiguredRightsFeed(
    Uri uri,
  ) async {
    final body = await _getJsonText(uri);

    final decoded = jsonDecode(body);

    final List<dynamic> list;

    if (decoded is Map && decoded['games'] is List) {
      list = decoded['games'] as List;
    } else if (decoded is List) {
      list = decoded;
    } else {
      return const [];
    }

    final games = <SportsGame>[];

    for (final raw in list) {
      if (raw is! Map) {
        continue;
      }

      try {
        games.add(
          _fromRightsJson(raw),
        );
      } catch (_) {
        // One malformed rights-feed event must not invalidate the feed.
      }
    }

    return games;
  }

  SportsGame _fromRightsJson(Map raw) {
    final rawId = raw['id']?.toString().trim();

    final id = rawId == null || rawId.isEmpty
        ? '${raw['homeTeam'] ?? 'home'}-${raw['awayTeam'] ?? 'away'}'
        : rawId;

    final broadcasts = <SportsBroadcast>[];

    final rawBroadcasts = raw['broadcasts'];

    if (rawBroadcasts is List) {
      for (final item in rawBroadcasts) {
        if (item is! Map) {
          continue;
        }

        final broadcastId =
            '${item['id'] ?? id}-broadcast';

        final streamUrl = _safeHttpsUrl(
          item['streamUrl']?.toString(),
        );

        final officialUrl = _safeHttpsUrl(
          item['officialUrl']?.toString(),
        );

        final authorized = item['authorized'] == true;
        final authenticOriginal =
            item['authenticOriginal'] == true;

        // A stream is not considered playable merely because the URL exists.
        // The rights provider must explicitly mark it authorized and
        // authentic/original.
        final playableStreamUrl =
            authorized && authenticOriginal
                ? streamUrl
                : null;

        broadcasts.add(
          SportsBroadcast(
            id: broadcastId,
            provider:
                _boundedString(
                  item['provider'],
                  fallback: 'Authorized provider',
                  maxLength: 200,
                ),
            country:
                _boundedString(
                  item['country'] ?? raw['country'],
                  fallback: 'International',
                  maxLength: 100,
                ),
            language:
                _boundedString(
                  item['language'],
                  fallback: 'Original',
                  maxLength: 100,
                ),
            commentary:
                _boundedString(
                  item['commentary'],
                  fallback: 'Original competition broadcast',
                  maxLength: 500,
                ),
            authenticOriginal: authenticOriginal,
            authorized: authorized,
            streamUrl: playableStreamUrl,
            officialUrl: officialUrl,
            freeToWatch: item['freeToWatch'] == true,
            includesHalftime:
                item['includesHalftime'] == true,
            includesCommercialBreaks:
                item['includesCommercialBreaks'] == true,
            broadcastType:
                _boundedString(
                  item['broadcastType'],
                  fallback: 'live',
                  maxLength: 50,
                ),
          ),
        );
      }
    }

    return SportsGame(
      id: id,
      sport: _boundedString(
        raw['sport'],
        fallback: 'Other',
        maxLength: 100,
      ),
      country: _boundedString(
        raw['country'],
        fallback: 'International',
        maxLength: 100,
      ),
      competition: _boundedString(
        raw['competition'],
        fallback: '',
        maxLength: 300,
      ),
      league: _boundedString(
        raw['league'] ?? raw['competition'],
        fallback: '',
        maxLength: 300,
      ),
      homeTeam: _boundedString(
        raw['homeTeam'],
        fallback: 'Home',
        maxLength: 200,
      ),
      awayTeam: _boundedString(
        raw['awayTeam'],
        fallback: 'Away',
        maxLength: 200,
      ),
      status: _boundedString(
        raw['status'],
        fallback: 'LIVE',
        maxLength: 100,
      ),
      homeScore: _intOrNull(raw['homeScore']),
      awayScore: _intOrNull(raw['awayScore']),
      periodLabel: _optionalString(
        raw['periodLabel'],
        maxLength: 100,
      ),
      clock: _optionalString(
        raw['clock'],
        maxLength: 100,
      ),
      startTime: _optionalString(
        raw['startTime'],
        maxLength: 100,
      ),
      broadcasts: List<SportsBroadcast>.unmodifiable(
        broadcasts,
      ),
    );
  }

  // ==========================================================
  // SCOREBOARD
  // ==========================================================

  Future<List<SportsGame>> _loadScoreboard(
    Map<String, String> feed, {
    String? date,
    bool upcomingOnly = false,
  }) async {
    final path = feed['path'];

    if (path == null || path.trim().isEmpty) {
      throw const FormatException('Invalid scoreboard feed path.');
    }

    var uri = Uri.parse(
      'https://site.api.espn.com/apis/site/v2/sports/$path/scoreboard',
    );

    if (date != null && date.isNotEmpty) {
      uri = uri.replace(
        queryParameters: {
          'dates': date,
        },
      );
    }

    final body = await _getJsonText(uri);
    final data = jsonDecode(body);

    if (data is! Map) {
      return const [];
    }

    final events = data['events'];

    if (events is! List) {
      return const [];
    }

    final games = <SportsGame>[];

    for (final event in events) {
      if (event is! Map) {
        continue;
      }

      if (upcomingOnly && !_isUpcoming(event)) {
        continue;
      }

      if (!upcomingOnly && !_isLive(event)) {
        continue;
      }

      try {
        games.add(
          _fromScoreboard(
            event,
            feed,
          ),
        );
      } catch (_) {
        // Ignore malformed individual events.
      }
    }

    return games;
  }

  bool _isUpcoming(Map event) {
    final status = event['status'];
    final type = status is Map ? status['type'] : null;
    final state =
        type is Map
            ? type['state']?.toString().toLowerCase()
            : null;

    return state == 'pre' || state == 'scheduled';
  }

  bool _isLive(Map event) {
    final status = event['status'];
    final type = status is Map ? status['type'] : null;
    final state =
        type is Map
            ? type['state']?.toString().toLowerCase()
            : null;

    return state == 'in';
  }

  SportsGame _fromScoreboard(
    Map event,
    Map<String, String> feed,
  ) {
    final competitions =
        event['competitions'] is List
            ? (event['competitions'] as List)
                .whereType<Map>()
                .toList()
            : <Map>[];

    final competition =
        competitions.isNotEmpty
            ? competitions.first
            : const <String, dynamic>{};

    final competitors =
        competition['competitors'] is List
            ? competition['competitors'] as List
            : const [];

    String team(String side) {
      for (final competitor in competitors.whereType<Map>()) {
        if (competitor['homeAway'] != side) {
          continue;
        }

        final teamData = competitor['team'];

        if (teamData is Map) {
          return _boundedString(
            teamData['displayName'] ??
                teamData['shortDisplayName'],
            fallback: side,
            maxLength: 200,
          );
        }
      }

      return side;
    }

    final status =
        event['status'] is Map
            ? event['status'] as Map
            : const {};

    final type =
        status['type'] is Map
            ? status['type'] as Map
            : const {};

    final competitionName = _boundedString(
      competition['name'],
      fallback: feed['path']!.split('/').last,
      maxLength: 300,
    );

    Map homeCompetitor = const {};
    Map awayCompetitor = const {};

    for (final competitor in competitors.whereType<Map>()) {
      if (competitor['homeAway'] == 'home') {
        homeCompetitor = competitor;
      } else if (competitor['homeAway'] == 'away') {
        awayCompetitor = competitor;
      }
    }

    final period = status['period'] ?? type['period'];
    final displayClock =
        status['displayClock'] ??
        type['displayClock'];

    final periodLabel = _periodLabel(
      period,
      feed['sport'],
    );

    final officialUrl = _firstOfficialUrl(
      event['links'],
    );

    final eventId =
        event['id']?.toString().trim();

    final id = eventId == null || eventId.isEmpty
        ? '${team('home')}-${team('away')}'
        : eventId;

    return SportsGame(
      id: id,
      sport: feed['sport']!,
      country: feed['country']!,
      competition: competitionName,
      league: feed['path']!.split('/').last,
      homeTeam: team('home'),
      awayTeam: team('away'),
      status: _boundedString(
        type['shortDetail'],
        fallback: 'LIVE',
        maxLength: 100,
      ),
      homeScore: _intOrNull(
        homeCompetitor['score'],
      ),
      awayScore: _intOrNull(
        awayCompetitor['score'],
      ),
      periodLabel: periodLabel,
      clock: _optionalString(
        displayClock,
        maxLength: 100,
      ),
      startTime: _optionalString(
        event['date'],
        maxLength: 100,
      ),

      // This is informational only. It intentionally cannot become a
      // playable stream.
      broadcasts: [
        SportsBroadcast(
          id: '$id-info',
          provider: 'Live scoreboard',
          country: feed['country']!,
          language: 'N/A',
          commentary:
              'Live game information. No streaming rights are implied.',
          authenticOriginal: false,
          authorized: false,
          streamUrl: null,
          officialUrl: officialUrl,
        ),
      ],
    );
  }

  String? _periodLabel(
    dynamic period,
    String? sport,
  ) {
    if (period == null) {
      return null;
    }

    final number = int.tryParse(
      period.toString(),
    );

    if (number == null || number < 1) {
      return 'Period $period';
    }

    if (sport == 'American Football' ||
        sport == 'Basketball') {
      return '$number${_ordinalSuffix(number)} Quarter';
    }

    if (sport == 'Hockey') {
      return '$number${_ordinalSuffix(number)} Period';
    }

    return 'Period $number';
  }

  String _ordinalSuffix(int number) {
    final mod100 = number % 100;

    if (mod100 >= 11 && mod100 <= 13) {
      return 'th';
    }

    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String? _firstOfficialUrl(dynamic links) {
    if (links is! List) {
      return null;
    }

    for (final link in links.whereType<Map>()) {
      final href = _safeHttpsUrl(
        link['href']?.toString(),
      );

      if (href != null) {
        return href;
      }
    }

    return null;
  }

  // ==========================================================
  // FILTERING
  // ==========================================================

  bool _feedMatches(
    Map<String, String> feed, {
    String? sport,
    String? country,
  }) {
    final feedSport =
        feed['sport']?.toLowerCase() ?? '';

    final feedCountry =
        feed['country']?.toLowerCase() ?? '';

    if (sport != null &&
        sport != 'all' &&
        feedSport != sport) {
      return false;
    }

    if (country != null &&
        country != 'all' &&
        feedCountry != country) {
      return false;
    }

    return true;
  }

  bool _gameMatches(
    SportsGame game, {
    String? sport,
    String? country,
  }) {
    final gameSport =
        game.sport.trim().toLowerCase();

    final gameCountry =
        game.country.trim().toLowerCase();

    if (sport != null &&
        sport != 'all' &&
        gameSport != sport) {
      return false;
    }

    if (country != null &&
        country != 'all' &&
        gameCountry != country) {
      return false;
    }

    return true;
  }

  String? _normalizeFilter(String? value) {
    final normalized =
        value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized.length > 100 ||
        _containsInvalidControlCharacter(normalized)) {
      throw Exception('Sports filter is invalid.');
    }

    return normalized;
  }

  // ==========================================================
  // HTTP
  // ==========================================================

  Future<String> _getJsonText(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException(
        'Sports endpoint must use HTTPS.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = _requestTimeout;

    try {
      final request = await client
          .getUrl(uri)
          .timeout(_requestTimeout);

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'StreamingServiceSports/1.0',
      );

      final response = await request
          .close()
          .timeout(_requestTimeout);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw HttpException(
          'Sports feed returned ${response.statusCode}.',
          uri: uri,
        );
      }

      final bytes = <int>[];

      await for (final chunk in response) {
        if (bytes.length + chunk.length >
            _maximumResponseBytes) {
          throw const FormatException(
            'Sports feed response is too large.',
          );
        }

        bytes.addAll(chunk);
      }

      return utf8.decode(
        bytes,
        allowMalformed: false,
      );
    } on TimeoutException {
      throw TimeoutException(
        'Sports feed request timed out.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Uri? _safeConfiguredFeedUri(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty) {
      return null;
    }

    return uri;
  }

  String? _safeHttpsUrl(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty ||
        normalized.length > 2048 ||
        _containsInvalidControlCharacter(normalized)) {
      return null;
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty) {
      return null;
    }

    return normalized;
  }

  // ==========================================================
  // VALUES
  // ==========================================================

  int? _intOrNull(dynamic value) {
    if (value is num) {
      return value.isFinite ? value.toInt() : null;
    }

    final parsed = int.tryParse(
      value?.toString().trim() ?? '',
    );

    return parsed;
  }

  String _boundedString(
    dynamic value, {
    required String fallback,
    required int maxLength,
  }) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return fallback;
    }

    if (text.length > maxLength) {
      return text.substring(0, maxLength);
    }

    if (_containsInvalidControlCharacter(text)) {
      return fallback;
    }

    return text;
  }

  String? _optionalString(
    dynamic value, {
    required int maxLength,
  }) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    if (text.length > maxLength ||
        _containsInvalidControlCharacter(text)) {
      return null;
    }

    return text;
  }

  bool _containsInvalidControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0 ||
          (codeUnit < 32 &&
              codeUnit != 9 &&
              codeUnit != 10 &&
              codeUnit != 13)) {
        return true;
      }
    }

    return false;
  }

  int _validateDays(int days) {
    if (days < minimumUpcomingDays ||
        days > maximumUpcomingDays) {
      throw Exception(
        'Upcoming sports days must be between '
        '$minimumUpcomingDays and $maximumUpcomingDays.',
      );
    }

    return days;
  }

  // ==========================================================
  // SORTING
  // ==========================================================

  int _compareGames(
    SportsGame a,
    SportsGame b,
  ) {
    final aTime =
        DateTime.tryParse(a.startTime ?? '');
    final bTime =
        DateTime.tryParse(b.startTime ?? '');

    if (aTime != null && bTime != null) {
      final comparison =
          aTime.compareTo(bTime);

      if (comparison != 0) {
        return comparison;
      }
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    return a.id.compareTo(b.id);
  }

  // ==========================================================
  // SUPPORTED SPORTS
  // ==========================================================

  List<String> sports() => const [
        'Soccer',
        'American Football',
        'Basketball',
        'Hockey',
        'Baseball',
        'Tennis',
        'Motorsports',
        'Boxing/MMA',
        'Volleyball',
        'Rugby',
        'Swimming/Athletics',
      ];

  // ==========================================================
  // LEAGUE LABELS
  // ==========================================================

  String _leagueLabel(
    Map<String, String> feed,
  ) {
    switch (feed['path']) {
      case 'football/nfl':
        return 'NFL';
      case 'basketball/nba':
        return 'NBA';
      case 'hockey/nhl':
        return 'NHL';
      case 'baseball/mlb':
        return 'MLB';
      case 'soccer/mex.1':
        return 'Liga MX';
      case 'soccer/usa.1':
        return 'MLS';
      case 'soccer/uefa.champions':
        return 'UEFA Champions League';
      case 'soccer/eng.1':
        return 'Premier League';
      case 'soccer/esp.1':
        return 'LaLiga';
      case 'soccer/ger.1':
        return 'Bundesliga';
      case 'soccer/ita.1':
        return 'Serie A';
      case 'soccer/fra.1':
        return 'Ligue 1';
      default:
        return feed['path']!.split('/').last;
    }
  }
}