// FILE: `Backend/services/sports_service.dart`.
// Purpose: Implements the sports service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../models/sports.dart';

/// Live sports feed with a real-time public scoreboard fallback.
///
/// The scoreboard feed supplies live event metadata/scores. It does NOT grant
/// streaming rights. A broadcast is playable only when an authorized
/// authentic/original stream URL is explicitly supplied by the configured
/// rights provider.
class SportsService {
  const SportsService();

  static const _espnFeeds = <Map<String, String>>[
    {'sport': 'American Football', 'country': 'United States', 'path': 'football/nfl'},
    {'sport': 'Basketball', 'country': 'United States', 'path': 'basketball/nba'},
    {'sport': 'Hockey', 'country': 'United States', 'path': 'hockey/nhl'},
    {'sport': 'Baseball', 'country': 'United States', 'path': 'baseball/mlb'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/eng.1'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/esp.1'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/ger.1'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/ita.1'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/fra.1'},
    {'sport': 'Soccer', 'country': 'Mexico', 'path': 'soccer/mex.1'},
    {'sport': 'Soccer', 'country': 'United States', 'path': 'soccer/usa.1'},
    {'sport': 'Soccer', 'country': 'International', 'path': 'soccer/uefa.champions'},
  ];

  Future<List<SportsGame>> liveGames({String? sport, String? country}) async {
    final results = <SportsGame>[];

    // A configured rights feed takes precedence because only it can provide
    // authorized authentic/original stream URLs.
    final configured = Platform.environment['SPORTS_RIGHTS_FEED_URL'];
    if (configured != null && configured.isNotEmpty) {
      try {
        results.addAll(await _loadConfiguredRightsFeed(Uri.parse(configured)));
      } catch (_) {
        // Fall through to live scoreboard metadata so the UI still shows what
        // is happening right now.
      }
    }

    if (results.isEmpty) {
  for (final feed in _espnFeeds) {
    if (sport != null &&
        sport.isNotEmpty &&
        feed['sport']!.toLowerCase() != sport.toLowerCase()) {
      continue;
    }

    if (country != null &&
        country.isNotEmpty &&
        feed['country']!.toLowerCase() != country.toLowerCase() &&
        !(feed['sport'] == 'Soccer' && country.toLowerCase() == 'all')) {
      continue;
    }

    try {
      results.addAll(await _loadScoreboard(feed));
    } catch (_) {
      // One unavailable league must not prevent other sports from loading.
    }
  }
}

    final seen = <String>{};
    return results.where((g) {
  if (sport != null &&
      sport.isNotEmpty &&
      sport.toLowerCase() != 'all' &&
      g.sport.toLowerCase() != sport.toLowerCase()) {
    return false;
  }

  if (country != null &&
      country.isNotEmpty &&
      country.toLowerCase() != 'all' &&
      g.country.toLowerCase() != country.toLowerCase()) {
    return false;
  }

  return seen.add(g.id);
}).toList();
  }

  Future<List<SportsGame>> upcomingGames({String? sport, String? country, int days = 7}) async {
    final results = <SportsGame>[];
    final now = DateTime.now();

    for (var offset = 1; offset <= days; offset++) {
      final date = now.add(Duration(days: offset));
      final dateCode = '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      for (final feed in _espnFeeds) {
        if (sport != null && sport.isNotEmpty && sport.toLowerCase() != 'all' && feed['sport']!.toLowerCase() != sport.toLowerCase()) continue;
        if (country != null && country.isNotEmpty && country.toLowerCase() != 'all' && feed['country']!.toLowerCase() != country.toLowerCase()) continue;
        try {
          results.addAll(await _loadScoreboard(feed, date: dateCode, upcomingOnly: true));
        } catch (_) {
          // One unavailable league/date must not prevent other events from loading.
        }
      }
    }

    final seen = <String>{};
    return results.where((g) => seen.add(g.id)).toList();
  }

  Future<List<SportsGame>> _loadConfiguredRightsFeed(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Sports rights feed returned ${response.statusCode}.',
        );
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      final list = decoded is Map && decoded['games'] is List
          ? decoded['games'] as List
          : decoded is List
              ? decoded
              : const [];
      return list.whereType<Map>().map(_fromRightsJson).toList();
    } finally {
      client.close(force: true);
    }
  }

  SportsGame _fromRightsJson(Map raw) {
    final broadcasts = raw['broadcasts'] is List
        ? (raw['broadcasts'] as List).whereType<Map>().map((b) => SportsBroadcast(
              id: '${b['id'] ?? raw['id']}-broadcast',
              provider: '${b['provider'] ?? 'Authorized provider'}',
              country: '${b['country'] ?? raw['country'] ?? 'International'}',
              language: '${b['language'] ?? 'Original'}',
              commentary: '${b['commentary'] ?? 'Original competition broadcast'}',
              authenticOriginal: b['authenticOriginal'] == true,
              authorized: b['authorized'] == true,
              streamUrl: b['streamUrl']?.toString(),
              officialUrl: b['officialUrl']?.toString(),
              freeToWatch: b['freeToWatch'] == true,
              includesHalftime: b['includesHalftime'] == true,
              includesCommercialBreaks: b['includesCommercialBreaks'] == true,
              broadcastType: '${b['broadcastType'] ?? 'live'}',
            )).toList()
        : <SportsBroadcast>[];
    return SportsGame(
      id: '${raw['id'] ?? raw['homeTeam']}-${raw['awayTeam']}',
      sport: '${raw['sport'] ?? 'Other'}',
      country: '${raw['country'] ?? 'International'}',
      competition: '${raw['competition'] ?? ''}',
      league: '${raw['league'] ?? raw['competition'] ?? ''}',
      homeTeam: '${raw['homeTeam'] ?? 'Home'}',
      awayTeam: '${raw['awayTeam'] ?? 'Away'}',
      status: '${raw['status'] ?? 'LIVE'}',
      startTime: raw['startTime']?.toString(),
      broadcasts: broadcasts,
    );
  }

  Future<List<SportsGame>> _loadScoreboard(Map<String, String> feed, {String? date, bool upcomingOnly = false}) async {
    var uri = Uri.parse('https://site.api.espn.com/apis/site/v2/sports/${feed['path']}/scoreboard');
    if (date != null) {
      uri = uri.replace(queryParameters: {'dates': date});
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Scoreboard returned ${response.statusCode}.');
      }
      final body = await utf8.decoder.bind(response).join();
      final data = jsonDecode(body);
      final events = data is Map && data['events'] is List ? data['events'] as List : const [];
      final mapped = events.whereType<Map>().where((e) => upcomingOnly ? _isUpcoming(e) : _isLive(e)).map((e) => _fromScoreboard(e, feed)).toList();
      return mapped;
    } finally {
      client.close(force: true);
    }
  }

  /// Performs `_isLive` for this feature. Update this documentation when its contract changes.
  bool _isUpcoming(Map event) {
    final status = event['status'];
    final type = status is Map ? status['type'] : null;
    final state = type is Map ? type['state']?.toString().toLowerCase() : null;
    return state == 'pre' || state == 'scheduled';
  }

  /// Performs `_isLive` for this feature. Update this documentation when its contract changes.
  bool _isLive(Map event) {
    final status = event['status'];
    final type = status is Map ? status['type'] : null;
    final state = type is Map ? type['state']?.toString().toLowerCase() : null;
    return state == 'in';
  }

  SportsGame _fromScoreboard(Map event, Map<String, String> feed) {
    final competitions = event['competitions'] is List ? (event['competitions'] as List).whereType<Map>().toList() : <Map>[];
    final competition = competitions.isNotEmpty ? competitions.first : const <String, dynamic>{};
    final competitors = competition['competitors'] is List ? competition['competitors'] as List : const [];
    /// Performs `team` for this feature. Update this documentation when its contract changes.
    String team(String side) {
      final matching = competitors.whereType<Map>().where((c) => c['homeAway'] == side).toList();
      final item = matching.isNotEmpty ? matching.first : null;
      final team = item?['team'];
      return team is Map ? '${team['displayName'] ?? team['shortDisplayName'] ?? side}' : side;
    }
    final status = event['status'] is Map ? event['status'] as Map : const {};
    final type = status['type'] is Map ? status['type'] as Map : const {};
    final competitionName = competition['name']?.toString() ?? feed['path']!.split('/').last;
    final links = event['links'] is List ? event['links'] as List : const [];
    String? officialUrl;
    for (final link in links.whereType<Map>()) {
      if (link['href'] != null) {
        officialUrl = link['href'].toString();
        break;
      }
    }
    return SportsGame(
      id: event['id']?.toString() ?? '${team('home')}-${team('away')}',
      sport: feed['sport']!,
      country: feed['country']!,
      competition: competitionName,
      league: feed['path']!.split('/').last,
      homeTeam: team('home'),
      awayTeam: team('away'),
      status: type['shortDetail']?.toString() ?? 'LIVE',
      startTime: event['date']?.toString(),
      broadcasts: [
        SportsBroadcast(
          id: '${event['id']}-info',
          provider: 'Live scoreboard',
          country: feed['country']!,
          language: 'N/A',
          commentary: 'Live game information. No streaming rights are implied.',
          authenticOriginal: false,
          authorized: false,
          officialUrl: officialUrl,
        ),
      ],
    );
  }

  /// Performs `sports` for this feature. Update this documentation when its contract changes.
  List<String> sports() => const [
        'Soccer', 'American Football', 'Basketball', 'Hockey', 'Baseball',
        'Tennis', 'Motorsports', 'Boxing/MMA', 'Volleyball', 'Rugby',
        'Swimming/Athletics'
      ];
}
