// FILE: `lib/sports.dart`.
// Purpose: Implements the sports portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';

class LiveSportsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const LiveSportsScreen({super.key, this.onBackToHome});

  @override
  State<LiveSportsScreen> createState() => _LiveSportsScreenState();
}

class _LiveSportsScreenState extends State<LiveSportsScreen> {
  String sport = 'All';
  String country = 'All';
  bool loading = true;
  bool upcomingLoading = true;
  String? error;
  String? upcomingError;
  List<Map<String, dynamic>> games = [];
  List<Map<String, dynamic>> upcomingGames = [];
  Set<String> followedTeams = <String>{};
  Set<String> followedLeagues = <String>{};

  static const sports = [
    'All', 'Soccer', 'American Football', 'Basketball', 'Hockey', 'Baseball',
    'Tennis', 'Motorsports', 'Boxing/MMA', 'Volleyball', 'Rugby', 'Swimming/Athletics',
  ];

  static const countries = [
    'All', 'Mexico', 'United States', 'England', 'Canada', 'International',
  ];

  static const leagues = <String>[
    'Liga MX', 'NFL', 'MLB', 'NBA', 'NHL', 'MLS', 'UEFA Champions League',
    'Premier League', 'LaLiga', 'Bundesliga', 'Serie A', 'Ligue 1',
  ];

  String get _profileKey => AppController.instance.currentProfile?.id ?? 'default';
  String get _teamsKey => 'sports_followed_teams_$_profileKey';
  String get _leaguesKey => 'sports_followed_leagues_$_profileKey';

  @override
  void initState() {
    super.initState();
    _loadFollows();
    _load();
    _loadUpcoming();
  }

  Future<void> _loadFollows() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      followedTeams = (prefs.getStringList(_teamsKey) ?? <String>[]).toSet();
      followedLeagues = (prefs.getStringList(_leaguesKey) ?? <String>[]).toSet();
    });
  }

  Future<void> _saveFollows() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_teamsKey, followedTeams.toList()..sort());
    await prefs.setStringList(_leaguesKey, followedLeagues.toList()..sort());
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await AppController.instance.backendApi.getLiveSports(
        sport: sport == 'All' ? null : sport,
        country: country == 'All' ? null : country,
      );
      final raw = data['games'];
      final next = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => games = next);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadUpcoming() async {
    if (mounted) setState(() { upcomingLoading = true; upcomingError = null; });
    try {
      final data = await AppController.instance.backendApi.getUpcomingSports(
        sport: sport == 'All' ? null : sport,
        country: country == 'All' ? null : country,
        days: 7,
      );
      final raw = data['games'];
      final next = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => upcomingGames = next);
    } catch (e) {
      if (!mounted) return;
      setState(() => upcomingError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => upcomingLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _loadUpcoming()]);
  }

  Future<void> _showFollowing() async {
    final selectedTeams = Set<String>.from(followedTeams);
    final selectedLeagues = Set<String>.from(followedLeagues);
    final searchController = TextEditingController();
    var search = '';
    var loadingTeams = true;
    List<Map<String, dynamic>> teamLeagues = <Map<String, dynamic>>[];

    try {
      final data = await AppController.instance.backendApi.getSportsTeams();
      final raw = data['leagues'];
      if (raw is List) {
        teamLeagues = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      // The dialog can still be used for league following if the team catalogue
      // is temporarily unavailable.
    } finally {
      loadingTeams = false;
    }

    if (!mounted) {
      searchController.dispose();
      return;
    }

    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalizedSearch = search.trim().toLowerCase();
          final filteredLeagues = teamLeagues.where((league) {
            if (normalizedSearch.isEmpty) return true;
            final leagueName = league['league']?.toString().toLowerCase() ?? '';
            if (leagueName.contains(normalizedSearch)) return true;
            final teams = league['teams'] is List ? league['teams'] as List : const [];
            return teams.any((item) => item is Map && (item['name']?.toString().toLowerCase().contains(normalizedSearch) ?? false));
          }).toList();

          return AlertDialog(
            title: const Text('Follow Teams & Leagues'),
            content: SizedBox(
              width: 560,
              height: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Follow any available team in any supported league. Followed teams get priority on Home when they are playing live.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    onChanged: (value) => setDialogState(() => search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search teams...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('LEAGUES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: loadingTeams
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            children: [
                              ...leagues.where((league) => normalizedSearch.isEmpty || league.toLowerCase().contains(normalizedSearch)).map(
                                (league) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: selectedLeagues.contains(league),
                                  title: Text(league),
                                  secondary: const Icon(Icons.emoji_events_outlined),
                                  onChanged: (value) => setDialogState(() {
                                    if (value == true) {
                                      selectedLeagues.add(league);
                                    } else {
                                      selectedLeagues.remove(league);
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final entry in filteredLeagues) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(entry['league']?.toString() ?? 'League', style: const TextStyle(fontWeight: FontWeight.w900))),
                                      Text('${(entry['teams'] is List ? (entry['teams'] as List).length : 0)} teams', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ...((entry['teams'] is List ? entry['teams'] as List : const [])
                                    .whereType<Map>()
                                    .where((team) {
                                      if (normalizedSearch.isEmpty) return true;
                                      return (team['name']?.toString().toLowerCase().contains(normalizedSearch) ?? false) ||
                                          (entry['league']?.toString().toLowerCase().contains(normalizedSearch) ?? false);
                                    })
                                    .map((team) {
                                      final name = team['name']?.toString() ?? '';
                                      return CheckboxListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.only(left: 8),
                                        value: selectedTeams.contains(name),
                                        title: Text(name),
                                        secondary: team['logo']?.toString().isNotEmpty == true
                                            ? Image.network(team['logo'].toString(), width: 30, height: 30, errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined))
                                            : const Icon(Icons.shield_outlined),
                                        onChanged: (value) => setDialogState(() {
                                          if (value == true) {
                                            selectedTeams.add(name);
                                          } else {
                                            selectedTeams.remove(name);
                                          }
                                        }),
                                      );
                                    })),
                              ],
                              if (filteredLeagues.isEmpty && normalizedSearch.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: Text('No teams or leagues match your search.')),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (changed != true || !mounted) return;
    setState(() {
      followedTeams = selectedTeams;
      followedLeagues = selectedLeagues;
    });
    await _saveFollows();
  }

  bool _matchesFollow(Map<String, dynamic> game) {
    final home = game['homeTeam']?.toString().toLowerCase() ?? '';
    final away = game['awayTeam']?.toString().toLowerCase() ?? '';
    final competition = game['competition']?.toString().toLowerCase() ?? '';
    final league = game['league']?.toString().toLowerCase() ?? '';
    return followedTeams.any((team) {
      final needle = team.toLowerCase();
      return home.contains(needle) || away.contains(needle);
    }) || followedLeagues.any((name) {
      final needle = name.toLowerCase();
      return competition.contains(needle) || league.contains(needle) ||
          (needle == 'nfl' && league.contains('nfl')) ||
          (needle == 'nba' && league.contains('nba')) ||
          (needle == 'mlb' && league.contains('mlb')) ||
          (needle == 'liga mx' && (competition.contains('liga mx') || league.contains('mex.1')));
    });
  }

  DateTime? _startTime(Map<String, dynamic> game) => DateTime.tryParse(game['startTime']?.toString() ?? '')?.toLocal();

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = date.difference(today).inDays;
    if (difference == 1) return 'Tomorrow';
    if (difference == 2) return 'In 2 days';
    if (difference > 2) return '${value.month}/${value.day}';
    return 'Today';
  }

  String _timeLabel(Map<String, dynamic> game) {
    final start = _startTime(game);
    if (start == null) return 'Time TBA';
    return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(start));
  }

  List<Map<String, dynamic>> _followedUpcoming() => upcomingGames.where(_matchesFollow).toList();

  @override
  Widget build(BuildContext context) {
    final followed = _followedUpcoming();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Live Sports'),
        actions: [
          IconButton(onPressed: _showFollowing, icon: const Icon(Icons.star_outline_rounded), tooltip: 'Follow teams and leagues'),
          IconButton(onPressed: loading || upcomingLoading ? null : _refreshAll, icon: const Icon(Icons.refresh), tooltip: 'Refresh sports'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GLOBAL LIVE SPORTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    const Text('Live scores are discovered from the scoreboard feed. Authorized original video broadcasts play directly inside this app.'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: sport,
                      items: sports.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                      onChanged: (v) { if (v != null) { setState(() => sport = v); _load(); _loadUpcoming(); } },
                      decoration: const InputDecoration(labelText: 'Sport', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: country,
                      items: countries.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                      onChanged: (v) { if (v != null) { setState(() => country = v); _load(); _loadUpcoming(); } },
                      decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _showFollowing, icon: const Icon(Icons.star_border), label: Text(followedTeams.isEmpty && followedLeagues.isEmpty ? 'Follow teams & leagues' : 'Manage following')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (followed.isNotEmpty) ...[
              const Text('FOLLOWING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70)),
              const SizedBox(height: 8),
              ...followed.take(8).map(_upcomingCard),
              const SizedBox(height: 10),
            ],
            const Text('LIVE NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70)),
            const SizedBox(height: 8),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
            if (!loading && error != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!))),
            if (!loading && error == null && games.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('There are no live games matching these filters right now.'))),
            ...games.map(_gameCard),
            const SizedBox(height: 20),
            const Text('UPCOMING GAMES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70)),
            const SizedBox(height: 8),
            if (upcomingLoading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
            if (!upcomingLoading && upcomingError != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(upcomingError!))),
            if (!upcomingLoading && upcomingError == null && upcomingGames.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No upcoming games were returned for these filters.'))),
            ..._groupUpcomingGames(),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupUpcomingGames() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final game in upcomingGames) {
      final start = _startTime(game);
      final label = start == null ? 'Upcoming' : _dateLabel(start);
      grouped.putIfAbsent(label, () => []).add(game);
    }
    final ordered = <String>['Tomorrow', 'In 2 days', 'In 3 days', 'In 4 days', 'In 5 days', 'In 6 days', 'In 7 days'];
    final widgets = <Widget>[];
    for (final label in ordered) {
      final entries = grouped[label];
      if (entries == null || entries.isEmpty) continue;
      widgets.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 8), child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))));
      widgets.addAll(entries.map(_upcomingCard));
    }
    return widgets;
  }

  Widget _upcomingCard(Map<String, dynamic> game) {
    final start = _startTime(game);
    final followed = _matchesFollow(game);
    final date = start == null ? 'Date TBA' : _dateLabel(start);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(followed ? Icons.star_rounded : Icons.schedule_rounded, color: followed ? Colors.amber : null),
        title: Text('${game['sport'] ?? 'Sport'} • $date', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_timeLabel(game)} • ${game['homeTeam'] ?? 'Home'} vs ${game['awayTeam'] ?? 'Away'}\n${game['competition'] ?? ''}'),
        isThreeLine: true,
      ),
    );
  }

  Widget _gameCard(Map<String, dynamic> game) {
    final broadcasts = game['broadcasts'] is List
        ? (game['broadcasts'] as List).whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
        : <Map<String, dynamic>>[];
    final playable = broadcasts.where((b) => b['authorized'] == true && b['authenticOriginal'] == true && (b['streamUrl']?.toString().isNotEmpty ?? false)).toList();
    final followed = _matchesFollow(game);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(followed ? Icons.star_rounded : Icons.circle, size: followed ? 18 : 10, color: followed ? Colors.amber : null),
              const SizedBox(width: 7),
              Expanded(child: Text(game['status']?.toString() ?? 'LIVE', style: const TextStyle(fontWeight: FontWeight.w900))),
              Flexible(child: Text(game['competition']?.toString() ?? '', textAlign: TextAlign.end)),
            ]),
            const SizedBox(height: 12),
            Text('${game['homeTeam']}  vs  ${game['awayTeam']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${game['sport']} • ${game['country']}'),
            if (followed) ...[
              const SizedBox(height: 6),
              const Text('Following', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 12),
            if (playable.isNotEmpty) ...playable.map((broadcast) => _broadcastTile(game, broadcast))
            else const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.live_tv_outlined), title: Text('Live game detected'), subtitle: Text('No authorized in-app video stream is attached to this game yet. Scores remain available.')),
          ],
        ),
      ),
    );
  }

  Widget _broadcastTile(Map<String, dynamic> game, Map<String, dynamic> broadcast) {
    final free = broadcast['freeToWatch'] == true;
    final halftime = broadcast['includesHalftime'] == true;
    final ads = broadcast['includesCommercialBreaks'] == true;
    final details = <String>[
      if (broadcast['language'] != null) broadcast['language'].toString(),
      if (free) 'FREE', if (halftime) 'Halftime included', if (ads) 'Original commercial breaks included',
    ];
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: const Icon(Icons.verified_rounded),
        title: Text(broadcast['provider']?.toString() ?? 'Authorized broadcast', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([broadcast['commentary']?.toString() ?? 'Original live broadcast', if (details.isNotEmpty) details.join(' • ')].join('\n')),
        isThreeLine: true,
        trailing: FilledButton.icon(
          onPressed: () {
            final url = broadcast['streamUrl']?.toString();
            if (url == null || url.isEmpty) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => SportsPlayerScreen(
              streamUrl: url,
              title: '${game['homeTeam']} vs ${game['awayTeam']}',
              provider: broadcast['provider']?.toString() ?? 'Authorized provider',
              originalBroadcast: broadcast['authenticOriginal'] == true,
              includesHalftime: halftime,
              includesCommercialBreaks: ads,
            )));
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('WATCH'),
        ),
      ),
    );
  }
}

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
  State<SportsPlayerScreen> createState() => _SportsPlayerScreenState();
}

class _SportsPlayerScreenState extends State<SportsPlayerScreen> {
  late final VideoPlayerController _controller;
  Future<void>? _initializeFuture;
  bool _muted = false;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
      ),
    );
    _initializeFuture = _initialize();
  }

  /// Performs `_initialize` for this feature. Update this documentation when its contract changes.
  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
      rethrow;
    }
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Performs `_togglePlayback` for this feature. Update this documentation when its contract changes.
  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  /// Performs `_toggleMute` for this feature. Update this documentation when its contract changes.
  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  /// Performs `_showError` for this feature. Update this documentation when its contract changes.
  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to play this broadcast: $error'),
      ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showError(snapshot.error!);
            });
            return _playerMessage(
              'This authorized broadcast could not be started on this device.',
            );
          }

          if (snapshot.connectionState != ConnectionState.done ||
              !_controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final aspectRatio = _controller.value.aspectRatio <= 0
              ? 16 / 9
              : _controller.value.aspectRatio;

          return Column(
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _togglePlayback,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return Center(
                                child: AnimatedOpacity(
                                  opacity: _controller.value.isPlaying ? 0 : 1,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      size: 42,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            '● LIVE',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlayback,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      tooltip: 'Play/Pause',
                    ),
                    IconButton(
                      onPressed: _toggleMute,
                      icon: Icon(
                        _muted ? Icons.volume_off : Icons.volume_up,
                      ),
                      tooltip: 'Mute',
                    ),
                    Expanded(
                      child: _controller.value.duration > Duration.zero &&
                              _controller.value.duration != Duration.zero
                          ? VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            )
                          : const Text('LIVE'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.provider,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.originalBroadcast)
                          const Chip(
                            avatar: Icon(Icons.verified, size: 18),
                            label: Text('Original broadcast'),
                          ),
                        if (widget.includesHalftime)
                          const Chip(label: Text('Halftime included')),
                        if (widget.includesCommercialBreaks)
                          const Chip(label: Text('Original commercial breaks')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Playback stays inside the streaming service. The available picture, halftime programming, commercial breaks, and other broadcast elements depend on what the authorized provider includes in this stream.',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Performs `_playerMessage` for this feature. Update this documentation when its contract changes.
  Widget _playerMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
