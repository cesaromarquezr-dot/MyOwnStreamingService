// FILE: `lib/sports.dart`.
// Purpose: Implements the sports portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'localization.dart';

/// Implements the `LiveSportsScreen` class for this feature or UI component.
class LiveSportsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const LiveSportsScreen({
    super.key,
    this.onBackToHome,
  });

  @override
  State<LiveSportsScreen> createState() => _LiveSportsScreenState();
}

/// Implements the `_LiveSportsScreenState` class for this feature or UI component.
class _LiveSportsScreenState extends State<LiveSportsScreen> {
  String sport = 'All';
  String country = 'All';

  bool loading = true;
  bool upcomingLoading = true;
  bool followingOnly = false;

  String? error;
  String? upcomingError;

  List<Map<String, dynamic>> games = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> upcomingGames = <Map<String, dynamic>>[];

  Set<String> followedTeams = <String>{};
  Set<String> followedLeagues = <String>{};

  int _requestGeneration = 0;

  static const sports = <String>[
    'All',
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

  static const countries = <String>[
    'All',
    'Mexico',
    'United States',
    'England',
    'Canada',
    'International',
  ];

  static const leagues = <String>[
    'Liga MX',
    'NFL',
    'MLB',
    'NBA',
    'NHL',
    'MLS',
    'UEFA Champions League',
    'Premier League',
    'LaLiga',
    'Bundesliga',
    'Serie A',
    'Ligue 1',
  ];

  String get _profileKey =>
      AppController.instance.currentProfile?.id ?? 'default';

  String get _teamsKey => 'sports_followed_teams_$_profileKey';

  String get _leaguesKey => 'sports_followed_leagues_$_profileKey';

  bool get _hasFollowing =>
      followedTeams.isNotEmpty || followedLeagues.isNotEmpty;

  int get _followedLiveCount =>
      games.where(_matchesFollow).length;

  int get _followedUpcomingCount =>
      upcomingGames.where(_matchesFollow).length;

  int get _followingCount =>
      followedTeams.length + followedLeagues.length;

  @override
  void initState() {
    super.initState();
    _loadFollows();
    _reloadAll();
  }

  Future<void> _loadFollows() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        followedTeams =
            (prefs.getStringList(_teamsKey) ?? <String>[]).toSet();
        followedLeagues =
            (prefs.getStringList(_leaguesKey) ?? <String>[]).toSet();

        if (!_hasFollowing) {
          followingOnly = false;
        }
      });
    } catch (_) {
      // Following is an enhancement. The sports screen remains usable
      // if local preference storage is temporarily unavailable.
    }
  }

  Future<void> _saveFollows() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _teamsKey,
      followedTeams.toList()..sort(),
    );

    await prefs.setStringList(
      _leaguesKey,
      followedLeagues.toList()..sort(),
    );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }

  Future<void> _reloadAll() async {
    final generation = ++_requestGeneration;

    if (mounted) {
      setState(() {
        loading = true;
        upcomingLoading = true;
        error = null;
        upcomingError = null;
      });
    }

    await Future.wait<void>([
      _loadLive(generation),
      _loadUpcoming(generation),
    ]);
  }

  Future<void> _loadLive(int generation) async {
    try {
      final data =
          await AppController.instance.backendApi.getLiveSports(
        sport: sport == 'All' ? null : sport,
        country: country == 'All' ? null : country,
      );

      final raw = data['games'];

      final next = raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => Map<String, dynamic>.from(e),
              )
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        games = next;
        error = null;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        error = _cleanError(e);
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadUpcoming(int generation) async {
    try {
      final data =
          await AppController.instance.backendApi.getUpcomingSports(
        sport: sport == 'All' ? null : sport,
        country: country == 'All' ? null : country,
        days: 7,
      );

      final raw = data['games'];

      final next = raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => Map<String, dynamic>.from(e),
              )
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        upcomingGames = next;
        upcomingError = null;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        upcomingError = _cleanError(e);
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          upcomingLoading = false;
        });
      }
    }
  }

  Future<void> _changeFilters({
    String? nextSport,
    String? nextCountry,
  }) async {
    final changedSport = nextSport != null && nextSport != sport;
    final changedCountry =
        nextCountry != null && nextCountry != country;

    if (!changedSport && !changedCountry) return;

    setState(() {
      if (nextSport != null) {
        sport = nextSport;
      }

      if (nextCountry != null) {
        country = nextCountry;
      }
    });

    await _reloadAll();
  }

  void _toggleFollowingOnly() {
    if (!_hasFollowing) {
      _showFollowing();
      return;
    }

    setState(() {
      followingOnly = !followingOnly;
    });
  }

  Future<void> _showFollowing() async {
    final selectedTeams = Set<String>.from(followedTeams);
    final selectedLeagues = Set<String>.from(followedLeagues);

    final searchController = TextEditingController();

    var search = '';
    var loadingTeams = true;

    List<Map<String, dynamic>> teamLeagues =
        <Map<String, dynamic>>[];

    try {
      final data =
          await AppController.instance.backendApi.getSportsTeams();

      final raw = data['leagues'];

      if (raw is List) {
        teamLeagues = raw
            .whereType<Map>()
            .map(
              (e) => Map<String, dynamic>.from(e),
            )
            .toList();
      }
    } catch (_) {
      // The dialog remains useful for static league following when
      // the optional team catalogue is unavailable.
    } finally {
      loadingTeams = false;
    }

    if (!mounted) {
      searchController.dispose();
      return;
    }

    final changed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.sizeOf(context);

        final dialogWidth = screenSize.width < 700
            ? screenSize.width - 32
            : 640.0;

        final dialogHeight = screenSize.height < 800
            ? screenSize.height * 0.76
            : 660.0;

        return AlertDialog(
          title: const UniversalText(
            'Follow Teams & Leagues',
          ),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final normalizedSearch =
                    search.trim().toLowerCase();

                final filteredLeagues = teamLeagues.where((league) {
                  if (normalizedSearch.isEmpty) return true;

                  final leagueName =
                      league['league']?.toString().toLowerCase() ?? '';

                  if (leagueName.contains(normalizedSearch)) {
                    return true;
                  }

                  final teams = league['teams'] is List
                      ? league['teams'] as List
                      : const [];

                  return teams.any(
                    (item) =>
                        item is Map &&
                        (item['name']
                                ?.toString()
                                .toLowerCase()
                                .contains(normalizedSearch) ??
                            false),
                  );
                }).toList();

                final totalSelected =
                    selectedTeams.length + selectedLeagues.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.45),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: UniversalText(
                              'Follow teams or leagues to keep them easy to find. Followed games are highlighted and can be shown in the dedicated Following view.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setDialogState(() {
                          search = value;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr('Search teams or leagues...'),
                        border: const OutlineInputBorder(),
                        suffixIcon: search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: tr('Clear search'),
                                onPressed: () {
                                  searchController.clear();

                                  setDialogState(() {
                                    search = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: UniversalText(
                            'FOLLOWING',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        if (totalSelected > 0)
                          Text(
                            '$totalSelected selected',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: totalSelected == 0
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedTeams.clear();
                                    selectedLeagues.clear();
                                  });
                                },
                          icon: const Icon(Icons.clear_all),
                          label: const UniversalText(
                            'Clear selection',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: loadingTeams
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : Scrollbar(
                              child: ListView(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                ),
                                children: [
                                  const UniversalText(
                                    'LEAGUES',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ..._dedupeStrings(
                                    leagues,
                                  )
                                      .where(
                                        (league) =>
                                            normalizedSearch.isEmpty ||
                                            league
                                                .toLowerCase()
                                                .contains(
                                                  normalizedSearch,
                                                ),
                                      )
                                      .map(
                                        (league) =>
                                            CheckboxListTile(
                                          dense: true,
                                          contentPadding:
                                              EdgeInsets.zero,
                                          value: selectedLeagues
                                              .contains(league),
                                          title: Text(league),
                                          secondary: const Icon(
                                            Icons
                                                .emoji_events_outlined,
                                          ),
                                          onChanged: (value) {
                                            setDialogState(() {
                                              if (value == true) {
                                                selectedLeagues.add(
                                                  league,
                                                );
                                              } else {
                                                selectedLeagues.remove(
                                                  league,
                                                );
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                  if (filteredLeagues.isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 14,
                                        bottom: 6,
                                      ),
                                      child: UniversalText(
                                        'AVAILABLE TEAMS',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.w900,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  for (final entry
                                      in filteredLeagues) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry['league']
                                                      ?.toString() ??
                                                  'League',
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          UniversalText(
                                            '${entry['teams'] is List ? (entry['teams'] as List).length : 0} teams',
                                            style:
                                                const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...((entry['teams'] is List
                                            ? entry['teams'] as List
                                            : const [])
                                        .whereType<Map>()
                                        .where((team) {
                                      if (normalizedSearch.isEmpty) {
                                        return true;
                                      }

                                      final teamName =
                                          team['name']
                                                  ?.toString()
                                                  .toLowerCase() ??
                                              '';

                                      final leagueName =
                                          entry['league']
                                                  ?.toString()
                                                  .toLowerCase() ??
                                              '';

                                      return teamName.contains(
                                            normalizedSearch,
                                          ) ||
                                          leagueName.contains(
                                            normalizedSearch,
                                          );
                                    }).map((team) {
                                      final name =
                                          team['name']?.toString() ?? '';

                                      final logo =
                                          team['logo']?.toString() ?? '';

                                      if (name.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return CheckboxListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.only(
                                          left: 8,
                                        ),
                                        value: selectedTeams.contains(
                                          name,
                                        ),
                                        title: Text(name),
                                        secondary: _teamLogo(
                                          logo,
                                          size: 32,
                                        ),
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (value == true) {
                                              selectedTeams.add(name);
                                            } else {
                                              selectedTeams.remove(name);
                                            }
                                          });
                                        },
                                      );
                                    })),
                                  ],
                                  if (filteredLeagues.isEmpty &&
                                      normalizedSearch.isNotEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(
                                        vertical: 30,
                                      ),
                                      child: Center(
                                        child: UniversalText(
                                          'No teams or leagues match your search.',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const UniversalText('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const UniversalText('Save'),
            ),
          ],
        );
      },
    );

    searchController.dispose();

    if (changed != true || !mounted) return;

    setState(() {
      followedTeams = selectedTeams;
      followedLeagues = selectedLeagues;

      if (!_hasFollowing) {
        followingOnly = false;
      }
    });

    await _saveFollows();
  }

  List<String> _dedupeStrings(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final normalized = value.trim().toLowerCase();

      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }

      seen.add(normalized);
      result.add(value);
    }

    return result;
  }

  bool _matchesFollow(Map<String, dynamic> game) {
    final home =
        game['homeTeam']?.toString().toLowerCase() ?? '';

    final away =
        game['awayTeam']?.toString().toLowerCase() ?? '';

    final competition =
        game['competition']?.toString().toLowerCase() ?? '';

    final league =
        game['league']?.toString().toLowerCase() ?? '';

    return followedTeams.any((team) {
          final needle = team.trim().toLowerCase();

          if (needle.isEmpty) return false;

          return home.contains(needle) ||
              away.contains(needle);
        }) ||
        followedLeagues.any((name) {
          final needle = name.trim().toLowerCase();

          if (needle.isEmpty) return false;

          return competition.contains(needle) ||
              league.contains(needle) ||
              (needle == 'nfl' && league.contains('nfl')) ||
              (needle == 'nba' && league.contains('nba')) ||
              (needle == 'mlb' && league.contains('mlb')) ||
              (needle == 'nhl' && league.contains('nhl')) ||
              (needle == 'liga mx' &&
                  (competition.contains('liga mx') ||
                      league.contains('mex.1')));
        });
  }

  DateTime? _startTime(Map<String, dynamic> game) {
    final candidates = [
      game['startTime'],
      game['start_time'],
      game['start'],
      game['scheduledAt'],
      game['scheduled_at'],
      game['date'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();

      if (value == null || value.isEmpty) {
        continue;
      }

      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    return null;
  }

  String _dateLabel(DateTime value) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final date = DateTime(
      value.year,
      value.month,
      value.day,
    );

    final difference = date.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';

    if (difference > 1 && difference <= 7) {
      return 'In $difference days';
    }

    return MaterialLocalizations.of(context).formatMediumDate(
      value,
    );
  }

  String _fullDateLabel(DateTime value) {
    return MaterialLocalizations.of(context).formatMediumDate(
      value,
    );
  }

  String _timeLabel(Map<String, dynamic> game) {
    final start = _startTime(game);

    if (start == null) return 'Time TBA';

    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
    );
  }

  List<Map<String, dynamic>> _filteredLiveGames() {
    final source = followingOnly
        ? games.where(_matchesFollow)
        : games;

    return _sortedGames(source);
  }

  List<Map<String, dynamic>> _filteredUpcomingGames() {
    final source = followingOnly
        ? upcomingGames.where(_matchesFollow)
        : upcomingGames;

    return _sortedGames(source);
  }

  List<Map<String, dynamic>> _sortedGames(
    Iterable<Map<String, dynamic>> source,
  ) {
    final result = source.toList();

    result.sort((a, b) {
      final followedA = _matchesFollow(a);
      final followedB = _matchesFollow(b);

      if (followedA != followedB) {
        return followedA ? -1 : 1;
      }

      final startA = _startTime(a);
      final startB = _startTime(b);

      if (startA == null && startB == null) {
        final statusA = _statusText(a).toLowerCase();
        final statusB = _statusText(b).toLowerCase();
        return statusA.compareTo(statusB);
      }

      if (startA == null) return 1;
      if (startB == null) return -1;

      return startA.compareTo(startB);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final horizontalPadding = width >= 1200
        ? 32.0
        : width >= 700
            ? 24.0
            : 16.0;

    final maxContentWidth = width >= 1400
        ? 1280.0
        : 1180.0;

    final liveGames = _filteredLiveGames();
    final filteredUpcoming = _filteredUpcomingGames();

    final followed = _sortedGames(
      upcomingGames.where(_matchesFollow),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onBackToHome == null,
        leading: widget.onBackToHome == null
            ? null
            : IconButton(
                onPressed: widget.onBackToHome,
                icon: const Icon(Icons.home_outlined),
                tooltip: tr('Back to home'),
              ),
        title: const UniversalText('Live Sports'),
        actions: [
          IconButton(
            onPressed: _showFollowing,
            icon: Icon(
              _hasFollowing
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: _hasFollowing ? Colors.amber : null,
            ),
            tooltip: tr('Follow teams and leagues'),
          ),
          IconButton(
            onPressed: loading || upcomingLoading
                ? null
                : _reloadAll,
            icon: const Icon(Icons.refresh),
            tooltip: tr('Refresh sports'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadAll,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                36,
              ),
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildFilterPanel(),
                const SizedBox(height: 18),
                _buildOverviewStats(),
                const SizedBox(height: 26),
                if (followingOnly) ...[
                  _buildFollowingModeBanner(),
                  const SizedBox(height: 20),
                ],
                if (followed.isNotEmpty && !followingOnly) ...[
                  _buildSectionHeader(
                    title: 'Following',
                    subtitle:
                        'Games involving teams or leagues you follow.',
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    trailing: TextButton(
                      onPressed: _showFollowing,
                      child: const UniversalText('Manage'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...followed.take(8).map(_upcomingCard),
                  if (followed.length > 8)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _toggleFollowingOnly,
                        child: UniversalText(
                          '+${followed.length - 8} more followed games',
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
                _buildSectionHeader(
                  title: 'Live Now',
                  subtitle: liveGames.isEmpty
                      ? followingOnly
                          ? 'No followed games are live with the current filters.'
                          : 'No live games match the current filters.'
                      : '${liveGames.length} live ${liveGames.length == 1 ? 'game' : 'games'}',
                  icon: Icons.circle,
                  iconColor: Colors.redAccent,
                ),
                const SizedBox(height: 10),
                if (loading)
                  _buildLoadingCard(
                    'Checking the live scoreboard...',
                  )
                else if (error != null)
                  _buildErrorCard(
                    error!,
                    onRetry: _reloadAll,
                  )
                else if (liveGames.isEmpty)
                  _buildEmptyCard(
                    icon: followingOnly
                        ? Icons.star_border_rounded
                        : Icons.sports_score_outlined,
                    title: followingOnly
                        ? 'No followed games are live'
                        : 'No live games right now',
                    message: followingOnly
                        ? 'Try another sport or country, or turn off the Following filter.'
                        : 'Try another sport or country, or check again later.',
                    actionLabel: followingOnly
                        ? 'Show all games'
                        : 'Refresh',
                    onAction: followingOnly
                        ? _toggleFollowingOnly
                        : _reloadAll,
                  )
                else
                  ...liveGames.map(_gameCard),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  title: 'Upcoming Games',
                  subtitle: followingOnly
                      ? 'Upcoming games involving teams or leagues you follow.'
                      : 'Scheduled games for the next 7 days.',
                  icon: Icons.calendar_month_outlined,
                ),
                const SizedBox(height: 10),
                if (upcomingLoading)
                  _buildLoadingCard(
                    'Loading the upcoming schedule...',
                  )
                else if (upcomingError != null)
                  _buildErrorCard(
                    upcomingError!,
                    onRetry: _loadUpcomingCurrentGeneration,
                  )
                else if (filteredUpcoming.isEmpty)
                  _buildEmptyCard(
                    icon: followingOnly
                        ? Icons.star_border_rounded
                        : Icons.event_busy_outlined,
                    title: followingOnly
                        ? 'No followed games are scheduled'
                        : 'No upcoming games',
                    message: followingOnly
                        ? 'Try another sport or country, or turn off the Following filter.'
                        : 'No games were returned for the selected filters.',
                    actionLabel: followingOnly
                        ? 'Show all games'
                        : 'Refresh',
                    onAction: followingOnly
                        ? _toggleFollowingOnly
                        : _reloadAll,
                  )
                else
                  ..._groupUpcomingGames(filteredUpcoming),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUpcomingCurrentGeneration() async {
    final generation = ++_requestGeneration;

    if (mounted) {
      setState(() {
        upcomingLoading = true;
        upcomingError = null;
      });
    }

    await _loadUpcoming(generation);
  }

  Widget _buildHeroHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.65),
              colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;

            final heading = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                  child: Icon(
                    Icons.sports_score_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      UniversalText(
                        'Sports Center',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      UniversalText(
                        'Live scores, schedules & authorized broadcasts',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final summary = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.circle,
                  loading
                      ? 'Live scoreboard'
                      : '${games.length} live',
                  iconColor: Colors.redAccent,
                ),
                _infoChip(
                  Icons.calendar_month_outlined,
                  upcomingLoading
                      ? 'Upcoming'
                      : '${upcomingGames.length} upcoming',
                ),
                _infoChip(
                  Icons.star_rounded,
                  _hasFollowing
                      ? '$_followingCount followed'
                      : 'Personal following',
                  iconColor: Colors.amber,
                ),
                const _HeroStatusChip(
                  icon: Icons.verified_rounded,
                  label: 'Authorized broadcasts',
                ),
              ],
            );

            final description = const UniversalText(
              'Discover live and upcoming games from the scoreboard feed. When an authorized original broadcast is available, you can watch it directly inside the streaming service.',
            );

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 16),
                  description,
                  const SizedBox(height: 16),
                  summary,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 16),
                description,
                const SizedBox(height: 16),
                summary,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.black.withValues(alpha: 0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;

            final sportField = DropdownButtonFormField<String>(
              initialValue: sport,
              isExpanded: true,
              items: sports
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _changeFilters(
                    nextSport: value,
                  );
                }
              },
              decoration: InputDecoration(
                labelText: tr('Sport'),
                prefixIcon: const Icon(Icons.sports_outlined),
                border: const OutlineInputBorder(),
              ),
            );

            final countryField = DropdownButtonFormField<String>(
              initialValue: country,
              isExpanded: true,
              items: countries
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _changeFilters(
                    nextCountry: value,
                  );
                }
              },
              decoration: InputDecoration(
                labelText: tr('Country'),
                prefixIcon: const Icon(Icons.public_outlined),
                border: const OutlineInputBorder(),
              ),
            );

            final followingButton = OutlinedButton.icon(
              onPressed: _toggleFollowingOnly,
              icon: Icon(
                followingOnly
                    ? Icons.star_rounded
                    : _hasFollowing
                        ? Icons.star_border_rounded
                        : Icons.add_circle_outline,
              ),
              label: UniversalText(
                followingOnly
                    ? 'Showing following'
                    : _hasFollowing
                        ? 'Following only'
                        : 'Follow teams & leagues',
              ),
            );

            final clearFilters = sport != 'All' ||
                country != 'All' ||
                followingOnly;

            if (compact) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: UniversalText(
                          'FILTERS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (clearFilters)
                        TextButton(
                          onPressed: () {
                            _changeFilters(
                              nextSport: 'All',
                              nextCountry: 'All',
                            );

                            if (followingOnly) {
                              setState(() {
                                followingOnly = false;
                              });
                            }
                          },
                          child: const UniversalText(
                            'Clear all',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  sportField,
                  const SizedBox(height: 12),
                  countryField,
                  const SizedBox(height: 12),
                  followingButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: UniversalText(
                        'FILTERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (clearFilters)
                      TextButton.icon(
                        onPressed: () {
                          _changeFilters(
                            nextSport: 'All',
                            nextCountry: 'All',
                          );

                          if (followingOnly) {
                            setState(() {
                              followingOnly = false;
                            });
                          }
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const UniversalText(
                          'Clear all',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sportField),
                    const SizedBox(width: 12),
                    Expanded(child: countryField),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: followingButton,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFollowingModeBanner() {
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.amber.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.star_rounded,
              color: Colors.amber,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  UniversalText(
                    'Following filter is active',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  UniversalText(
                    'Only games involving your followed teams or leagues are shown.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _toggleFollowingOnly,
              child: const UniversalText('Show all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;

        final cards = [
          _statCard(
            icon: Icons.circle,
            label: 'Live',
            value: loading ? '—' : '${games.length}',
            color: Colors.redAccent,
          ),
          _statCard(
            icon: Icons.calendar_today_outlined,
            label: 'Upcoming',
            value: upcomingLoading
                ? '—'
                : '${upcomingGames.length}',
          ),
          _statCard(
            icon: Icons.star_rounded,
            label: 'Following',
            value: '$_followingCount',
            color: Colors.amber,
          ),
          _statCard(
            icon: Icons.star_outline_rounded,
            label: 'Followed games',
            value:
                '${_followedLiveCount + _followedUpcomingCount}',
          ),
        ];

        if (columns == 1) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
  }) {
    final resolvedColor =
        iconColor ?? Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: resolvedColor.withValues(alpha: 0.12),
          ),
          child: Icon(
            icon,
            size: icon == Icons.circle ? 11 : 19,
            color: resolvedColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildLoadingCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: UniversalText(message),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    String message, {
    required VoidCallback onRetry,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const UniversalText(
                    'Sports feed unavailable',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const UniversalText(
                      'Try again',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Icon(
              icon,
              size: 44,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            UniversalText(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            UniversalText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
            if (actionLabel != null &&
                onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: UniversalText(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _groupUpcomingGames(
    List<Map<String, dynamic>> source,
  ) {
    final sorted = _sortedGames(source);

    final grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final game in sorted) {
      final start = _startTime(game);

      final label = start == null
          ? 'Date TBA'
          : _dateLabel(start);

      grouped.putIfAbsent(
        label,
        () => <Map<String, dynamic>>[],
      ).add(game);
    }

    final orderedLabels = <String>[
      'Today',
      'Tomorrow',
      'In 2 days',
      'In 3 days',
      'In 4 days',
      'In 5 days',
      'In 6 days',
      'In 7 days',
      'Date TBA',
    ];

    final widgets = <Widget>[];
    final consumed = <String>{};

    for (final label in orderedLabels) {
      final entries = grouped[label];

      if (entries == null || entries.isEmpty) {
        continue;
      }

      consumed.add(label);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.addAll(
        entries.map(_upcomingCard),
      );
    }

    final remaining = grouped.entries
        .where((entry) => !consumed.contains(entry.key))
        .toList();

    for (final entry in remaining) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${entry.value.length}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.addAll(
        entry.value.map(_upcomingCard),
      );
    }

    return widgets;
  }

  Widget _upcomingCard(
    Map<String, dynamic> game,
  ) {
    final start = _startTime(game);
    final followed = _matchesFollow(game);

    final home =
        _stringValue(game, ['homeTeam', 'home', 'home_name']) ??
            'Home';

    final away =
        _stringValue(game, ['awayTeam', 'away', 'away_name']) ??
            'Away';

    final competition =
        _stringValue(game, ['competition']) ?? '';

    final league =
        _stringValue(game, ['league']) ?? '';

    final sportName =
        _stringValue(game, ['sport']) ?? 'Sport';

    final location =
        _stringValue(game, ['country']) ?? '';

    final hasBroadcast = _hasAuthorizedBroadcast(game);

    final homeLogo = _firstImageValue(
      game,
      const [
        'homeLogo',
        'homeTeamLogo',
        'homeLogoUrl',
      ],
    );

    final awayLogo = _firstImageValue(
      game,
      const [
        'awayLogo',
        'awayTeamLogo',
        'awayLogoUrl',
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                _sportBadge(sportName),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    competition.isNotEmpty
                        ? competition
                        : league.isNotEmpty
                            ? league
                            : sportName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (followed)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 19,
                    ),
                  ),
                if (hasBroadcast)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.live_tv_outlined,
                      size: 19,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 460;

                final homeWidget = _teamDisplay(
                  home,
                  logo: homeLogo,
                  alignment: CrossAxisAlignment.end,
                  textAlign: TextAlign.end,
                );

                final awayWidget = _teamDisplay(
                  away,
                  logo: awayLogo,
                  alignment: CrossAxisAlignment.start,
                  textAlign: TextAlign.start,
                );

                final timeWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      start == null
                          ? 'TBA'
                          : _timeLabel(game),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (start != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _fullDateLabel(start),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                );

                if (compact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: homeWidget),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            child: timeWidget,
                          ),
                          Expanded(child: awayWidget),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Expanded(child: homeWidget),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: timeWidget,
                    ),
                    Expanded(child: awayWidget),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _smallPill(sportName),
                      if (location.isNotEmpty)
                        _smallPill(
                          location,
                          icon: Icons.public,
                        ),
                      if (followed)
                        _smallPill(
                          'Following',
                          icon: Icons.star_rounded,
                          iconColor: Colors.amber,
                        ),
                    ],
                  ),
                ),
                if (hasBroadcast)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Broadcast available',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamDisplay(
    String name, {
    String? logo,
    required CrossAxisAlignment alignment,
    required TextAlign textAlign,
  }) {
    return Row(
      mainAxisAlignment: alignment == CrossAxisAlignment.end
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (alignment == CrossAxisAlignment.end &&
            logo != null &&
            logo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _teamLogo(logo),
          ),
        Flexible(
          child: Text(
            name,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (alignment == CrossAxisAlignment.start &&
            logo != null &&
            logo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _teamLogo(logo),
          ),
      ],
    );
  }

  Widget _teamLogo(
    String? url, {
    double size = 38,
  }) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Icon(
          Icons.shield_outlined,
          size: size * 0.52,
          color: Colors.white38,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Icon(
            Icons.shield_outlined,
            size: size * 0.52,
            color: Colors.white38,
          );
        },
        loadingBuilder: (
          context,
          child,
          progress,
        ) {
          if (progress == null) return child;

          return const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }

  String? _firstImageValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String? _stringValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Widget _sportBadge(String sportName) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.12),
      ),
      child: Text(
        sportName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _smallPill(
    String label, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: iconColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(
    Map<String, dynamic> game,
  ) {
    final broadcasts = game['broadcasts'] is List
        ? (game['broadcasts'] as List)
            .whereType<Map>()
            .map(
              (x) => Map<String, dynamic>.from(x),
            )
            .toList()
        : <Map<String, dynamic>>[];

    final playable = broadcasts
        .where(_isPlayableBroadcast)
        .toList();

    final followed = _matchesFollow(game);

    final home =
        _stringValue(game, ['homeTeam', 'home']) ?? 'Home';

    final away =
        _stringValue(game, ['awayTeam', 'away']) ?? 'Away';

    final competition =
        _stringValue(game, ['competition']) ?? '';

    final league =
        _stringValue(game, ['league']) ?? '';

    final status = _statusText(game);

    final sportName =
        _stringValue(game, ['sport']) ?? 'Sport';

    final countryName =
        _stringValue(game, ['country']) ?? '';

    final score = _scoreLabel(game);

    final homeLogo = _firstImageValue(
      game,
      const [
        'homeLogo',
        'homeTeamLogo',
        'homeLogoUrl',
      ],
    );

    final awayLogo = _firstImageValue(
      game,
      const [
        'awayLogo',
        'awayTeamLogo',
        'awayLogoUrl',
      ],
    );

    final gameDetails = _gameStatusDetails(game);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 4,
              color: followed
                  ? Colors.amber
                  : Colors.redAccent,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _liveBadge(),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          competition.isNotEmpty
                              ? competition
                              : league.isNotEmpty
                                  ? league
                                  : sportName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (countryName.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 3,
                            ),
                            child: Text(
                              '$sportName • $countryName',
                              style:
                                  const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (followed) _followingBadge(),
                ],
              ),
              const SizedBox(height: 17),
              _liveTeamsRow(
                home: home,
                away: away,
                score: score,
                homeLogo: homeLogo,
                awayLogo: awayLogo,
              ),
              if (gameDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: gameDetails
                      .map(
                        (item) => _smallPill(
                          item,
                          icon: Icons.timer_outlined,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  _statusPill(status),
                  const Spacer(),
                  if (playable.isNotEmpty)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.live_tv_rounded,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Watch live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 13),
              if (playable.isNotEmpty)
                ...playable.map(
                  (broadcast) => _broadcastTile(
                    game,
                    broadcast,
                  ),
                )
              else
                _noBroadcastTile(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveTeamsRow({
    required String home,
    required String away,
    required String score,
    String? homeLogo,
    String? awayLogo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;

        final homeTeam = _liveTeam(
          name: home,
          logo: homeLogo,
          alignment: CrossAxisAlignment.end,
          textAlign: TextAlign.end,
        );

        final awayTeam = _liveTeam(
          name: away,
          logo: awayLogo,
          alignment: CrossAxisAlignment.start,
          textAlign: TextAlign.start,
        );

        final scoreWidget = Container(
          constraints: const BoxConstraints(
            minWidth: 82,
          ),
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: Column(
            children: [
              const Text(
                'SCORE',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  color: Colors.white38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                score,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

        return Row(
          children: [
            Expanded(child: homeTeam),
            scoreWidget,
            Expanded(child: awayTeam),
          ],
        );
      },
    );
  }

  Widget _liveTeam({
    required String name,
    required String? logo,
    required CrossAxisAlignment alignment,
    required TextAlign textAlign,
  }) {
    final logoWidget = logo == null || logo.isEmpty
        ? null
        : _teamLogo(
            logo,
            size: 42,
          );

    final nameWidget = Flexible(
      child: Text(
        name,
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final label = Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        alignment == CrossAxisAlignment.end
            ? 'HOME'
            : 'AWAY',
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1,
          color: Colors.white38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment:
              alignment == CrossAxisAlignment.end
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
          children: [
            if (alignment == CrossAxisAlignment.end &&
                logoWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: logoWidget,
              ),
            nameWidget,
            if (alignment == CrossAxisAlignment.start &&
                logoWidget != null)
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: logoWidget,
              ),
          ],
        ),
        label,
      ],
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.redAccent.withValues(
          alpha: 0.16,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Colors.redAccent,
          ),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.redAccent,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _followingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.amber.withValues(
          alpha: 0.12,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 15,
            color: Colors.amber,
          ),
          SizedBox(width: 4),
          Text(
            'Following',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.redAccent.withValues(
          alpha: 0.1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.redAccent,
        ),
      ),
    );
  }

  String _statusText(Map<String, dynamic> game) {
    final value = _stringValue(
      game,
      const [
        'status',
        'state',
        'gameStatus',
      ],
    );

    if (value == null || value.isEmpty) {
      return 'LIVE';
    }

    return value;
  }

  List<String> _gameStatusDetails(
    Map<String, dynamic> game,
  ) {
    final details = <String>[];

    final clock = _stringValue(
      game,
      const [
        'clock',
        'gameClock',
        'timeRemaining',
      ],
    );

    final period = _stringValue(
      game,
      const [
        'period',
        'quarter',
        'inning',
        'set',
        'round',
      ],
    );

    final minute = _stringValue(
      game,
      const [
        'minute',
        'elapsed',
        'elapsedMinutes',
      ],
    );

    if (clock != null && clock.isNotEmpty) {
      details.add(clock);
    }

    if (period != null && period.isNotEmpty) {
      details.add(period);
    }

    if (minute != null && minute.isNotEmpty) {
      details.add(minute.contains("'")
          ? minute
          : "$minute'");
    }

    return _dedupeStrings(details);
  }

  String _scoreLabel(Map<String, dynamic> game) {
    final homeScore = _scoreValue(
      game,
      const [
        'homeScore',
        'homeTeamScore',
        'home_score',
      ],
    );

    final awayScore = _scoreValue(
      game,
      const [
        'awayScore',
        'awayTeamScore',
        'away_score',
      ],
    );

    if (homeScore != null || awayScore != null) {
      return '${homeScore ?? '-'} - ${awayScore ?? '-'}';
    }

    final score = game['score'];

    if (score is Map) {
      final nestedHome = _nestedScoreValue(
        score,
        const [
          'home',
          'homeScore',
          'home_score',
        ],
      );

      final nestedAway = _nestedScoreValue(
        score,
        const [
          'away',
          'awayScore',
          'away_score',
        ],
      );

      if (nestedHome != null || nestedAway != null) {
        return '${nestedHome ?? '-'} - ${nestedAway ?? '-'}';
      }
    }

    final home = game['home'];

    if (home is Map) {
      final nestedHome = _nestedScoreValue(
        home,
        const [
          'score',
          'points',
          'goals',
        ],
      );

      final away = game['away'];

      if (away is Map) {
        final nestedAway = _nestedScoreValue(
          away,
          const [
            'score',
            'points',
            'goals',
          ],
        );

        if (nestedHome != null || nestedAway != null) {
          return '${nestedHome ?? '-'} - ${nestedAway ?? '-'}';
        }
      }
    }

    final directScore = game['score'];

    if (directScore != null &&
        directScore is! Map &&
        directScore.toString().trim().isNotEmpty) {
      return directScore.toString();
    }

    return '—';
  }

  dynamic _scoreValue(
    Map<String, dynamic> game,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = game[key];

      if (_isUsableScore(value)) {
        return value;
      }
    }

    return null;
  }

  dynamic _nestedScoreValue(
    Map<dynamic, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];

      if (_isUsableScore(value)) {
        return value;
      }
    }

    return null;
  }

  bool _isUsableScore(dynamic value) {
    if (value == null) return false;

    if (value is num) return true;

    final text = value.toString().trim();

    return text.isNotEmpty;
  }

  bool _isPlayableBroadcast(
    Map<String, dynamic> broadcast,
  ) {
    final streamUrl =
        broadcast['streamUrl']?.toString().trim() ?? '';

    return broadcast['authorized'] == true &&
        broadcast['authenticOriginal'] == true &&
        _isValidStreamUrl(streamUrl);
  }

  bool _isValidStreamUrl(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);

    if (uri == null) return false;

    return uri.hasScheme &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https');
  }

  bool _hasAuthorizedBroadcast(
    Map<String, dynamic> game,
  ) {
    final broadcasts = game['broadcasts'];

    if (broadcasts is! List) return false;

    return broadcasts.any(
      (item) =>
          item is Map &&
          _isPlayableBroadcast(
            Map<String, dynamic>.from(item),
          ),
    );
  }

  Widget _noBroadcastTile() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(
          alpha: 0.04,
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 20,
            color: Colors.white54,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                UniversalText(
                  'Live game detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                UniversalText(
                  'No authorized in-app video stream is attached to this game yet. Scores remain available.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _broadcastTile(
    Map<String, dynamic> game,
    Map<String, dynamic> broadcast,
  ) {
    final free =
        broadcast['freeToWatch'] == true;

    final halftime =
        broadcast['includesHalftime'] == true;

    final ads =
        broadcast['includesCommercialBreaks'] == true;

    final provider =
        broadcast['provider']?.toString() ??
            'Authorized broadcast';

    final commentary =
        broadcast['commentary']?.toString() ??
            'Original live broadcast';

    final details = <String>[
      if (broadcast['language'] != null)
        broadcast['language'].toString(),
      if (free) 'FREE',
      if (halftime) 'Halftime included',
      if (ads)
        'Original commercial breaks included',
    ];

    final streamUrl =
        broadcast['streamUrl']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.06,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;

          final information = Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(
                    alpha: 0.12,
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      commentary,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: details
                            .map(
                              (item) => _smallPill(
                                item,
                                icon: item == 'FREE'
                                    ? Icons.lock_open_rounded
                                    : null,
                                iconColor:
                                    Colors.greenAccent,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: _isValidStreamUrl(streamUrl)
                ? () => _openBroadcast(
                      game,
                      broadcast,
                      provider,
                      halftime,
                      ads,
                      streamUrl,
                    )
                : null,
            icon: const Icon(
              Icons.play_arrow_rounded,
            ),
            label: const UniversalText('WATCH LIVE'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                information,
                const SizedBox(height: 12),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  void _openBroadcast(
    Map<String, dynamic> game,
    Map<String, dynamic> broadcast,
    String provider,
    bool halftime,
    bool ads,
    String streamUrl,
  ) {
    if (!_isValidStreamUrl(streamUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UniversalText(
            'This broadcast does not contain a valid stream URL.',
          ),
        ),
      );
      return;
    }

    final home =
        _stringValue(game, ['homeTeam', 'home']) ?? 'Home';

    final away =
        _stringValue(game, ['awayTeam', 'away']) ?? 'Away';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SportsPlayerScreen(
          streamUrl: streamUrl,
          title: '$home vs $away',
          provider: provider,
          originalBroadcast:
              broadcast['authenticOriginal'] == true,
          includesHalftime: halftime,
          includesCommercialBreaks: ads,
        ),
      ),
    );
  }
}

/// Implements the `SportsPlayerScreen` class for this feature or UI component.
class SportsPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String provider;
  final bool originalBroadcast;
  final bool includesHalftime;
  final bool includesCommercialBreaks;

  const SportsPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    required this.provider,
    required this.originalBroadcast,
    required this.includesHalftime,
    required this.includesCommercialBreaks,
  });

  @override
  State<SportsPlayerScreen> createState() =>
      _SportsPlayerScreenState();
}

/// Implements the `_SportsPlayerScreenState` class for this feature or UI component.
class _SportsPlayerScreenState
    extends State<SportsPlayerScreen> {
  VideoPlayerController? _controller;

  Future<void>? _initializeFuture;

  bool _muted = false;
  bool _showControls = true;
  bool _initializationFailed = false;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    final oldController = _controller;

    _controller = null;
    _initializeFuture = null;
    _initializationFailed = false;
    _initializationError = null;

    oldController?.dispose();

    final uri = Uri.tryParse(widget.streamUrl);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      _initializationFailed = true;
      _initializationError =
          'The broadcast URL is invalid.';
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
      ),
    );

    _controller = controller;
    _initializeFuture =
        _initializeController(controller);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeController(
    VideoPlayerController controller,
  ) async {
    try {
      await controller.initialize();
      await controller.setLooping(false);

      if (!mounted || _controller != controller) {
        return;
      }

      try {
        await controller.play();
      } catch (_) {
        // Some platforms/providers require the first play command
        // to happen after a user gesture. The controls remain
        // available if autoplay is rejected.
      }

      if (mounted && _controller == controller) {
        setState(() {
          _initializationFailed = false;
          _initializationError = null;
        });
      }
    } catch (error) {
      if (mounted && _controller == controller) {
        setState(() {
          _initializationFailed = true;
          _initializationError = error;
        });
      }

      rethrow;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;

    controller?.dispose();

    super.dispose();
  }

  Future<void> _retry() async {
    if (!mounted) return;

    final oldController = _controller;

    setState(() {
      _controller = null;
      _initializeFuture = null;
      _initializationFailed = false;
      _initializationError = null;
    });

    await oldController?.dispose();

    if (!mounted) return;

    _createController();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final nextMuted = !_muted;

    await controller.setVolume(
      nextMuted ? 0 : 1,
    );

    if (mounted) {
      setState(() {
        _muted = nextMuted;
      });
    }
  }

  void _toggleControls() {
    if (!mounted) return;

    setState(() {
      _showControls = !_showControls;
    });
  }

  Future<void> _seekRelative(
    Duration offset,
  ) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;

    if (duration <= Duration.zero) {
      return;
    }

    final current = controller.value.position;
    var target = current + offset;

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    if (target > duration) {
      target = duration;
    }

    await controller.seekTo(target);

    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60);
    final seconds =
        duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final future = _initializeFuture;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: future == null || controller == null
          ? _playerErrorView(
              _initializationError?.toString() ??
                  'This authorized broadcast could not be started.',
            )
          : FutureBuilder<void>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError ||
                    _initializationFailed) {
                  return _playerErrorView(
                    _initializationError?.toString() ??
                        snapshot.error?.toString() ??
                        'This authorized broadcast could not be started on this device.',
                  );
                }

                if (snapshot.connectionState !=
                        ConnectionState.done ||
                    !controller.value.isInitialized) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        UniversalText(
                          'Starting authorized broadcast...',
                        ),
                      ],
                    ),
                  );
                }

                return _buildInitializedPlayer(
                  controller,
                );
              },
            ),
    );
  }

  Widget _buildInitializedPlayer(
    VideoPlayerController controller,
  ) {
    final aspectRatio =
        controller.value.aspectRatio <= 0
            ? 16 / 9
            : controller.value.aspectRatio;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: aspectRatio,
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: VideoPlayer(controller),
                ),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        if (_showControls)
                          Positioned.fill(
                            child: _buildPlayerOverlay(
                              controller,
                            ),
                          ),
                        if (controller.value.isBuffering)
                          const Center(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          color: Colors.black,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final position =
                  controller.value.position;

              final duration =
                  controller.value.duration;

              final hasDuration =
                  duration > Duration.zero;

              return Column(
                children: [
                  if (hasDuration)
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 4,
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _togglePlayback,
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        tooltip: tr('Play/Pause'),
                      ),
                      IconButton(
                        onPressed: () =>
                            _seekRelative(
                          const Duration(seconds: -10),
                        ),
                        icon: const Icon(
                          Icons.replay_10_rounded,
                        ),
                        tooltip: tr('Back 10 seconds'),
                      ),
                      IconButton(
                        onPressed: () =>
                            _seekRelative(
                          const Duration(seconds: 10),
                        ),
                        icon: const Icon(
                          Icons.forward_10_rounded,
                        ),
                        tooltip: tr('Forward 10 seconds'),
                      ),
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        tooltip: tr('Mute'),
                      ),
                      const SizedBox(width: 4),
                      if (hasDuration)
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        )
                      else
                        const UniversalText(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      const Spacer(),
                      if (controller.value.isBuffering)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: UniversalText(
                            'BUFFERING',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        )
                      else if (controller.value.isPlaying)
                        const UniversalText(
                          'PLAYING',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              28,
            ),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 500;

                  if (compact) {
                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _playerLiveBadge(),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _playerLiveBadge(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                widget.provider,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _buildBroadcastInfo(),
              const SizedBox(height: 18),
              const UniversalText(
                'Playback stays inside the streaming service. The available picture, halftime programming, commercial breaks, and other broadcast elements depend on what the authorized provider includes in this stream.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerOverlay(
    VideoPlayerController controller,
  ) {
    final playing = controller.value.isPlaying;

    return Stack(
      children: [
        Center(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: playing ? 0.0 : 1.0,
              duration: const Duration(
                milliseconds: 150,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _playerLiveBadge(),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _playerOverlayControls(),
        ),
      ],
    );
  }

  Widget _playerOverlayControls() {
    final controller = _controller;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(
          alpha: 0.55,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              controller?.value.isPlaying == true
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            tooltip: tr('Play/Pause'),
          ),
          IconButton(
            onPressed: _toggleMute,
            icon: Icon(
              _muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
            tooltip: tr('Mute'),
          ),
          const Spacer(),
          const UniversalText(
            'AUTHORIZED BROADCAST',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const UniversalText(
        '● LIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildBroadcastInfo() {
    final chips = <Widget>[
      if (widget.originalBroadcast)
        const Chip(
          avatar: Icon(
            Icons.verified_rounded,
            size: 18,
          ),
          label: UniversalText(
            'Original broadcast',
          ),
        ),
      if (widget.includesHalftime)
        const Chip(
          avatar: Icon(
            Icons.pause_circle_outline,
            size: 18,
          ),
          label: UniversalText(
            'Halftime included',
          ),
        ),
      if (widget.includesCommercialBreaks)
        const Chip(
          avatar: Icon(
            Icons.tv_outlined,
            size: 18,
          ),
          label: UniversalText(
            'Original commercial breaks',
          ),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const UniversalText(
              'BROADCAST DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (chips.isEmpty)
              const UniversalText(
                'Broadcast metadata was not provided by the source.',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playerErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.live_tv_outlined,
                    size: 52,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 16),
                  const UniversalText(
                    'Unable to play broadcast',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  UniversalText(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(
                          Icons.refresh,
                        ),
                        label: const UniversalText(
                          'Retry',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                        ),
                        label: const UniversalText(
                          'Go back',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small reusable hero status chip.
class _HeroStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatusChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.black.withValues(alpha: 0.16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.greenAccent,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}