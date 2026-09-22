// FILE: `Backend/models/sports.dart`.
// Purpose: Implements the sports portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Sports metadata describes games and authorized broadcast associations.
// Authorization is a backend/provider concern; the presence of a URL alone
// does not grant permission to stream content.

class SportsBroadcast {
  final String id;
  final String provider;
  final String country;
  final String language;
  final String commentary;
  final bool authenticOriginal;
  final bool authorized;
  final bool freeToWatch;
  final bool includesHalftime;
  final bool includesCommercialBreaks;
  final String broadcastType;
  final String? streamUrl;
  final String? officialUrl;

  const SportsBroadcast({
    required this.id,
    required this.provider,
    required this.country,
    required this.language,
    required this.commentary,
    required this.authenticOriginal,
    required this.authorized,
    this.freeToWatch = false,
    this.includesHalftime = false,
    this.includesCommercialBreaks = false,
    this.broadcastType = 'live',
    this.streamUrl,
    this.officialUrl,
  });

  bool get hasStreamUrl =>
      streamUrl != null && streamUrl!.trim().isNotEmpty;

  bool get hasOfficialUrl =>
      officialUrl != null && officialUrl!.trim().isNotEmpty;

  /// A URL being present is not enough to make a broadcast playable.
  ///
  /// The broadcast must be explicitly authorized, marked as the intended
  /// authentic/original broadcast, and have a stream URL.
  bool get playableInApp =>
      authorized &&
      authenticOriginal &&
      hasStreamUrl;

  bool get isValid =>
      id.trim().isNotEmpty &&
      provider.trim().isNotEmpty &&
      country.trim().isNotEmpty &&
      language.trim().isNotEmpty &&
      commentary.trim().isNotEmpty &&
      broadcastType.trim().isNotEmpty;

  bool get isLiveBroadcast =>
      broadcastType.trim().toLowerCase() == 'live';

  SportsBroadcast copyWith({
    String? id,
    String? provider,
    String? country,
    String? language,
    String? commentary,
    bool? authenticOriginal,
    bool? authorized,
    bool? freeToWatch,
    bool? includesHalftime,
    bool? includesCommercialBreaks,
    String? broadcastType,
    String? streamUrl,
    String? officialUrl,
    bool clearStreamUrl = false,
    bool clearOfficialUrl = false,
  }) {
    return SportsBroadcast(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      country: country ?? this.country,
      language: language ?? this.language,
      commentary: commentary ?? this.commentary,
      authenticOriginal:
          authenticOriginal ?? this.authenticOriginal,
      authorized: authorized ?? this.authorized,
      freeToWatch: freeToWatch ?? this.freeToWatch,
      includesHalftime:
          includesHalftime ?? this.includesHalftime,
      includesCommercialBreaks:
          includesCommercialBreaks ?? this.includesCommercialBreaks,
      broadcastType: broadcastType ?? this.broadcastType,
      streamUrl:
          clearStreamUrl ? null : (streamUrl ?? this.streamUrl),
      officialUrl:
          clearOfficialUrl ? null : (officialUrl ?? this.officialUrl),
    );
  }

  /// Performs `fromJson` for this feature.
  factory SportsBroadcast.fromJson(Map<String, dynamic> json) {
    return SportsBroadcast(
      id: _stringValue(json['id']),
      provider: _stringValue(json['provider']),
      country: _stringValue(json['country']),
      language: _stringValue(json['language']),
      commentary: _stringValue(json['commentary']),
      authenticOriginal:
          _boolValue(json['authenticOriginal']),
      authorized: _boolValue(json['authorized']),
      freeToWatch: _boolValue(json['freeToWatch']),
      includesHalftime:
          _boolValue(json['includesHalftime']),
      includesCommercialBreaks:
          _boolValue(json['includesCommercialBreaks']),
      broadcastType: _stringValue(
        json['broadcastType'],
        fallback: 'live',
      ),
      streamUrl: _nullableString(json['streamUrl']),
      officialUrl: _nullableString(json['officialUrl']),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// `playableInApp` is derived state and is included for API/UI convenience;
  /// it is not an independent persisted authorization flag.
  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'country': country,
        'language': language,
        'commentary': commentary,
        'authenticOriginal': authenticOriginal,
        'authorized': authorized,
        'freeToWatch': freeToWatch,
        'includesHalftime': includesHalftime,
        'includesCommercialBreaks': includesCommercialBreaks,
        'broadcastType': broadcastType,
        'streamUrl': streamUrl,
        'officialUrl': officialUrl,
        'playableInApp': playableInApp,
      };

  @override
  String toString() {
    return 'SportsBroadcast('
        'id: $id, '
        'provider: $provider, '
        'country: $country, '
        'language: $language, '
        'commentary: $commentary, '
        'authenticOriginal: $authenticOriginal, '
        'authorized: $authorized, '
        'freeToWatch: $freeToWatch, '
        'includesHalftime: $includesHalftime, '
        'includesCommercialBreaks: $includesCommercialBreaks, '
        'broadcastType: $broadcastType, '
        'hasStreamUrl: $hasStreamUrl, '
        'hasOfficialUrl: $hasOfficialUrl'
        ')';
  }
}

class SportsGame {
  final String id;
  final String sport;
  final String country;
  final String competition;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final String? periodLabel;
  final String? clock;
  final String? startTime;
  final List<SportsBroadcast> broadcasts;

  const SportsGame({
    required this.id,
    required this.sport,
    required this.country,
    required this.competition,
    this.league = '',
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.periodLabel,
    this.clock,
    this.startTime,
    this.broadcasts = const [],
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      sport.trim().isNotEmpty &&
      country.trim().isNotEmpty &&
      competition.trim().isNotEmpty &&
      homeTeam.trim().isNotEmpty &&
      awayTeam.trim().isNotEmpty &&
      status.trim().isNotEmpty;

  bool get hasScore =>
      homeScore != null || awayScore != null;

  bool get hasStarted {
    final normalized = status.trim().toLowerCase();

    return normalized == 'live' ||
        normalized == 'in_progress' ||
        normalized == 'in-progress' ||
        normalized == 'halftime' ||
        normalized == 'paused' ||
        normalized == 'finished' ||
        normalized == 'final' ||
        hasScore;
  }

  bool get hasEnded {
    final normalized = status.trim().toLowerCase();

    return normalized == 'finished' ||
        normalized == 'final' ||
        normalized == 'completed' ||
        normalized == 'ended';
  }

  bool get hasUpcomingStartTime =>
      startTime != null && startTime!.trim().isNotEmpty;

  Iterable<SportsBroadcast> get authorizedOriginalBroadcasts =>
      broadcasts.where((broadcast) => broadcast.playableInApp);

  Iterable<SportsBroadcast> get authorizedBroadcasts =>
      broadcasts.where((broadcast) => broadcast.authorized);

  Iterable<SportsBroadcast> get freeBroadcasts =>
      broadcasts.where(
        (broadcast) =>
            broadcast.authorized && broadcast.freeToWatch,
      );

  bool get hasAuthenticOriginalBroadcast =>
      authorizedOriginalBroadcasts.isNotEmpty;

  bool get hasAnyAuthorizedBroadcast =>
      authorizedBroadcasts.isNotEmpty;

  SportsGame copyWith({
    String? id,
    String? sport,
    String? country,
    String? competition,
    String? league,
    String? homeTeam,
    String? awayTeam,
    String? status,
    int? homeScore,
    int? awayScore,
    String? periodLabel,
    String? clock,
    String? startTime,
    List<SportsBroadcast>? broadcasts,
    bool clearLeague = false,
    bool clearHomeScore = false,
    bool clearAwayScore = false,
    bool clearPeriodLabel = false,
    bool clearClock = false,
    bool clearStartTime = false,
  }) {
    return SportsGame(
      id: id ?? this.id,
      sport: sport ?? this.sport,
      country: country ?? this.country,
      competition: competition ?? this.competition,
      league: clearLeague ? '' : (league ?? this.league),
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      status: status ?? this.status,
      homeScore:
          clearHomeScore ? null : (homeScore ?? this.homeScore),
      awayScore:
          clearAwayScore ? null : (awayScore ?? this.awayScore),
      periodLabel:
          clearPeriodLabel ? null : (periodLabel ?? this.periodLabel),
      clock: clearClock ? null : (clock ?? this.clock),
      startTime:
          clearStartTime ? null : (startTime ?? this.startTime),
      broadcasts:
          List<SportsBroadcast>.unmodifiable(
            broadcasts ?? this.broadcasts,
          ),
    );
  }

  /// Performs `fromJson` for this feature.
  factory SportsGame.fromJson(Map<String, dynamic> json) {
    final rawBroadcasts = json['broadcasts'];

    final parsedBroadcasts = <SportsBroadcast>[];

    if (rawBroadcasts is List) {
      for (final value in rawBroadcasts) {
        if (value is Map) {
          parsedBroadcasts.add(
            SportsBroadcast.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
    }

    return SportsGame(
      id: _stringValue(json['id']),
      sport: _stringValue(json['sport']),
      country: _stringValue(json['country']),
      competition: _stringValue(json['competition']),
      league: _stringValue(json['league']),
      homeTeam: _stringValue(json['homeTeam']),
      awayTeam: _stringValue(json['awayTeam']),
      status: _stringValue(json['status']),
      homeScore: _nullableInt(json['homeScore']),
      awayScore: _nullableInt(json['awayScore']),
      periodLabel: _nullableString(json['periodLabel']),
      clock: _nullableString(json['clock']),
      startTime: _nullableString(json['startTime']),
      broadcasts:
          List<SportsBroadcast>.unmodifiable(parsedBroadcasts),
    );
  }

  /// Performs `toJson` for this feature.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport,
        'country': country,
        'competition': competition,
        'league': league,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'status': status,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'periodLabel': periodLabel,
        'clock': clock,
        'startTime': startTime,
        'broadcasts':
            broadcasts.map((broadcast) => broadcast.toJson()).toList(),
        'hasAuthenticOriginalBroadcast':
            hasAuthenticOriginalBroadcast,
      };

  @override
  String toString() {
    return 'SportsGame('
        'id: $id, '
        'sport: $sport, '
        'country: $country, '
        'competition: $competition, '
        'league: $league, '
        'homeTeam: $homeTeam, '
        'awayTeam: $awayTeam, '
        'status: $status, '
        'homeScore: $homeScore, '
        'awayScore: $awayScore, '
        'periodLabel: $periodLabel, '
        'clock: $clock, '
        'startTime: $startTime, '
        'broadcastCount: ${broadcasts.length}'
        ')';
  }
}

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _boolValue(
  dynamic value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
    }
  }

  return fallback;
}

int? _nullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}