// FILE: `Backend/models/sports.dart`.
// Purpose: Implements the sports portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

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

  bool get playableInApp =>
      authorized && authenticOriginal && streamUrl != null && streamUrl!.isNotEmpty;

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
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

  Iterable<SportsBroadcast> get authorizedOriginalBroadcasts =>
      broadcasts.where((b) => b.playableInApp);

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
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
        'broadcasts': broadcasts.map((b) => b.toJson()).toList(),
        'hasAuthenticOriginalBroadcast': authorizedOriginalBroadcasts.isNotEmpty,
      };
}
