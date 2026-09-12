// Home widgets for live scores and customizable server-storage visualization.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'music.dart';

class HomeLiveSportsWidget extends StatefulWidget {
  const HomeLiveSportsWidget({super.key});

  @override
  State<HomeLiveSportsWidget> createState() => _HomeLiveSportsWidgetState();
}

class _HomeLiveSportsWidgetState extends State<HomeLiveSportsWidget> {
  List<Map<String, dynamic>> liveGames = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> upcomingGames = <Map<String, dynamic>>[];
  Set<String> followedTeams = <String>{};
  Set<String> followedLeagues = <String>{};
  Set<String> visibleLeagues = <String>{};
  bool loading = true;
  Timer? _refreshTimer;
  Timer? _autoScrollTimer;
  final ScrollController _liveScrollController = ScrollController();

  static const List<String> _availableLeagues = <String>[
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

  String get _profileKey => AppController.instance.currentProfile?.id ?? 'default';
  String get _teamsKey => 'sports_followed_teams_$_profileKey';
  String get _leaguesKey => 'sports_followed_leagues_$_profileKey';
  String get _visibleLeaguesKey => 'sports_home_visible_leagues_$_profileKey';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _autoScrollLiveGames());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _autoScrollTimer?.cancel();
    _liveScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final storedVisible = prefs.getStringList(_visibleLeaguesKey);
    final nextTeams = (prefs.getStringList(_teamsKey) ?? <String>[]).toSet();
    final nextLeagues = (prefs.getStringList(_leaguesKey) ?? <String>[]).toSet();
    final nextVisible = storedVisible == null || storedVisible.isEmpty
        ? _availableLeagues.toSet()
        : storedVisible.toSet();

    if (mounted) {
      setState(() {
        followedTeams = nextTeams;
        followedLeagues = nextLeagues;
        visibleLeagues = nextVisible;
      });
    }

    // Load live scores independently. A slow/failing upcoming-games request
    // must never prevent the live scoreboard from appearing on Home.
    try {
      final data = await AppController.instance.backendApi.getLiveSports();
      final raw = data['games'];
      final live = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          liveGames = live;
          loading = false;
        });
        if (_liveScrollController.hasClients) {
          _liveScrollController.jumpTo(0);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          liveGames = <Map<String, dynamic>>[];
          loading = false;
        });
      }
    }

    // Upcoming games are supplemental and load separately so they cannot
    // block live scores.
    try {
      final data = await AppController.instance.backendApi.getUpcomingSports(days: 7);
      final raw = data['games'];
      final upcoming = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => upcomingGames = upcoming);
    } catch (_) {
      if (mounted) setState(() => upcomingGames = <Map<String, dynamic>>[]);
    }
  }

  bool _matchesFollow(Map<String, dynamic> game) {
    final home = game['homeTeam']?.toString().toLowerCase() ?? '';
    final away = game['awayTeam']?.toString().toLowerCase() ?? '';
    final competition = game['competition']?.toString().toLowerCase() ?? '';
    final league = game['league']?.toString().toLowerCase() ?? '';

    if (followedTeams.any((team) {
      final needle = team.toLowerCase();
      return home.contains(needle) || away.contains(needle);
    })) {
      return true;
    }

    return followedLeagues.any((name) {
      final needle = name.toLowerCase();
      return competition.contains(needle) || league.contains(needle);
    });
  }

  bool _matchesVisibleLeague(Map<String, dynamic> game) {
    if (visibleLeagues.length == _availableLeagues.length) return true;
    if (visibleLeagues.isEmpty) return false;
    final league = (game['league']?.toString() ?? '').toLowerCase();
    final competition = (game['competition']?.toString() ?? '').toLowerCase();
    return visibleLeagues.any((name) {
      final needle = name.toLowerCase();
      return league.contains(needle) || competition.contains(needle) ||
          (needle == 'liga mx' && (league.contains('mex.1') || competition.contains('liga mx')));
    });
  }

  List<Map<String, dynamic>> get _filteredLiveGames =>
      liveGames.where(_matchesVisibleLeague).toList();

  List<Map<String, dynamic>> get _priorityLiveGames {
    final available = _filteredLiveGames;
    final followedLive = available.where(_matchesFollow).toList();
    return followedLive.isNotEmpty ? followedLive : available;
  }

  List<Map<String, dynamic>> get _sortedUpcoming {
    final result = upcomingGames.where(_matchesVisibleLeague).toList();
    result.sort((a, b) {
      final af = _matchesFollow(a);
      final bf = _matchesFollow(b);
      if (af != bf) return af ? -1 : 1;
      final at = DateTime.tryParse(a['startTime']?.toString() ?? '') ?? DateTime(2100);
      final bt = DateTime.tryParse(b['startTime']?.toString() ?? '') ?? DateTime(2100);
      return at.compareTo(bt);
    });
    return result;
  }

  String _score(Map<String, dynamic> game, String side) {
    final value = game['${side}Score'];
    return value?.toString() ?? '-';
  }

  String _liveDetail(Map<String, dynamic> game) {
    final period = game['periodLabel']?.toString();
    final clock = game['clock']?.toString();
    final status = game['status']?.toString() ?? 'LIVE';
    if (period != null && period.isNotEmpty && clock != null && clock.isNotEmpty) {
      return '$period • $clock remaining';
    }
    if (period != null && period.isNotEmpty) return period;
    return status;
  }

  void _autoScrollLiveGames() {
    if (!mounted || !_liveScrollController.hasClients) return;
    final max = _liveScrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final next = _liveScrollController.offset + 300;
    _liveScrollController.animateTo(
      next >= max ? 0 : next,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _chooseVisibleLeagues() async {
    final selected = Set<String>.from(visibleLeagues.isEmpty ? _availableLeagues : visibleLeagues);
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sports shown on Home'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Choose which leagues appear in the Home Live Sports ticker. Your team/league follows remain separate.'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show all leagues'),
                  value: selected.length == _availableLeagues.length,
                  onChanged: (value) => setDialogState(() {
                    selected
                      ..clear()
                      ..addAll(value == true ? _availableLeagues : const <String>[]);
                  }),
                ),
                const Divider(),
                ..._availableLeagues.map((league) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(league),
                  value: selected.contains(league),
                  onChanged: (value) => setDialogState(() {
                    if (value == true) {
                      selected.add(league);
                    } else {
                      selected.remove(league);
                    }
                  }),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (changed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_visibleLeaguesKey, selected.toList()..sort());
    setState(() => visibleLeagues = selected);
    if (_liveScrollController.hasClients) _liveScrollController.jumpTo(0);
  }

  String _upcomingTime(Map<String, dynamic> game) {
    final value = DateTime.tryParse(game['startTime']?.toString() ?? '')?.toLocal();
    if (value == null) return 'Time TBA';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = day.difference(today).inDays;
    final label = diff == 1
        ? 'Tomorrow'
        : diff == 2
            ? 'In 2 days'
            : '${value.month}/${value.day}';
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$label • $time';
  }

  @override
  Widget build(BuildContext context) {
    final live = _priorityLiveGames;
    final upcoming = _sortedUpcoming.take(8).toList();
    final followedLive = live.any(_matchesFollow);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_score_rounded),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LIVE SPORTS',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Choose leagues shown on Home',
                  onPressed: _chooseVisibleLeagues,
                  icon: const Icon(Icons.filter_list_rounded),
                ),
                IconButton(
                  tooltip: 'Refresh scores',
                  onPressed: loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (!loading && live.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No live games are available right now.'),
              ),
            if (followedLive && live.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'A followed team is playing — showing only followed-team live games.',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            if (live.isNotEmpty)
              SizedBox(
                height: 170,
                child: Scrollbar(
                  controller: _liveScrollController,
                  thumbVisibility: live.length > 1,
                  child: ListView.separated(
                    controller: _liveScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: live.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) => SizedBox(width: 300, child: _liveGame(live[index])),
                  ),
                ),
              ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'UPCOMING',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              const SizedBox(height: 6),
              for (final game in upcoming) _upcomingGame(game),
            ],
          ],
        ),
      ),
    );
  }

  Widget _liveGame(Map<String, dynamic> game) {
    final followed = _matchesFollow(game);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: followed ? Colors.amber.withValues(alpha: .08) : Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: followed ? Colors.amber.withValues(alpha: .30) : Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (followed) const Icon(Icons.star_rounded, size: 17, color: Colors.amber),
              if (followed) const SizedBox(width: 5),
              const Icon(Icons.circle, size: 8, color: Colors.redAccent),
              const SizedBox(width: 6),
              Expanded(child: Text('${game['sport'] ?? 'Sports'} • LIVE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
              Text(_liveDetail(game), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(game['homeTeam']?.toString() ?? 'Home', style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(_score(game, 'home'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(game['awayTeam']?.toString() ?? 'Away', style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(_score(game, 'away'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 3),
          Text(game['competition']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _upcomingGame(Map<String, dynamic> game) {
    final followed = _matchesFollow(game);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(followed ? Icons.star_rounded : Icons.schedule_rounded, color: followed ? Colors.amber : null),
      title: Text(
        '${game['homeTeam'] ?? 'Home'}  vs  ${game['awayTeam'] ?? 'Away'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('${_upcomingTime(game)} • ${game['competition'] ?? ''}'),
    );
  }
}

class HomeStorageProgressBar extends StatelessWidget {
  final double thickness;
  final Axis axis;
  const HomeStorageProgressBar({super.key, required this.thickness, required this.axis});

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final total = (account?.storageLimitBytes ?? 1000000000000).toDouble();
    final used = (account?.storageUsedBytes ?? 0).toDouble().clamp(0, total);
    final media = AppController.instance.library;
    final movies = media.where((m) => m.type.toLowerCase() == 'movie').length.toDouble();
    final series = media.where((m) => m.type.toLowerCase().contains('tv') || m.type.toLowerCase().contains('series') || m.type.toLowerCase().contains('show')).length.toDouble();
    final music = MusicStorageCount.value;
    final contentUnits = movies + series + music;
    final available = (total - used).clamp(0, total).toDouble();
    final portions = <String, double>{
      'Movies': contentUnits == 0 ? 0 : used * (movies / contentUnits),
      'Series': contentUnits == 0 ? 0 : used * (series / contentUnits),
      'Music': contentUnits == 0 ? 0 : used * (music / contentUnits),
      'Available': available,
    };
    final labels = <Widget>[];
    for (final entry in portions.entries) {
      final fraction = entry.value / total;
      labels.add(Expanded(flex: (fraction * 1000).round().clamp(1, 1000), child: Tooltip(message: '${entry.key}: ${(entry.value / total * 100).toStringAsFixed(1)}%', child: Container(margin: const EdgeInsets.symmetric(horizontal: .5), height: thickness, decoration: BoxDecoration(color: _categoryColor(entry.key))))));
    }
    final bar = ClipRRect(borderRadius: BorderRadius.circular(thickness), child: axis == Axis.horizontal ? Row(children: labels) : Column(children: labels));
    final legend = <Widget>[];
    for (final entry in portions.entries) {
      legend.add(Expanded(child: Text(entry.key, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60))));
    }
    return Padding(padding: const EdgeInsets.all(10), child: axis == Axis.horizontal ? Column(children: [bar, const SizedBox(height: 5), Row(children: legend)]) : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [SizedBox(width: thickness, height: 210, child: bar), const SizedBox(width: 7), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: legend))]));
  }

  Color _categoryColor(String key) => switch (key) { 'Movies' => Colors.redAccent, 'Series' => Colors.blueAccent, 'Music' => Colors.purpleAccent, _ => Colors.greenAccent };
}


class HomePositionedLayout extends StatelessWidget {
  final String navbarPosition;
  final String storagePosition;
  final String liveSportsPosition;
  final double storageThickness;
  final bool showLiveSports;
  final Widget navbar;
  final Widget child;

  const HomePositionedLayout({
    super.key,
    required this.navbarPosition,
    required this.storagePosition,
    required this.liveSportsPosition,
    required this.storageThickness,
    required this.showLiveSports,
    required this.navbar,
    required this.child,
  });

  static const _sides = <String>['Top', 'Bottom', 'Left', 'Right'];

  // Resolves requested sides while preserving the requested side whenever it is
  // available. If 2 or 3 items request the same side, they are distributed
  // across that edge instead of being stacked on top of each other.
  List<String> _resolveSides() {
    final requests = <String>[
      if (_sides.contains(navbarPosition)) navbarPosition else 'Floating',
      if (_sides.contains(storagePosition)) storagePosition else 'Hidden',
      if (showLiveSports && _sides.contains(liveSportsPosition)) liveSportsPosition else 'Hidden',
    ];

    final result = List<String>.filled(3, 'Hidden');
    for (var i = 0; i < requests.length; i++) {
      final requested = requests[i];
      if (requested == 'Hidden' || requested == 'Floating') continue;
      result[i] = requested;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final sides = _resolveSides();
    final visible = <int>[for (var i = 0; i < sides.length; i++) if (sides[i] != 'Hidden' && (i != 2 || showLiveSports)) i];

    final bySide = <String, List<int>>{for (final side in _sides) side: <int>[]};
    for (final index in visible) {
      final side = sides[index];
      if (side != 'Hidden') bySide[side]!.add(index);
    }

    Widget itemFor(int index) {
      if (index == 0) return navbar;
      if (index == 1) {
        return HomeStorageProgressBar(
          thickness: storageThickness,
          axis: sides[index] == 'Left' || sides[index] == 'Right' ? Axis.vertical : Axis.horizontal,
        );
      }
      // Index 2 is the Live Sports display. The previous implementation
      // accidentally returned another storage bar here, so Live Sports could
      // never be rendered even when enabled.
      return const HomeLiveSportsWidget();
    }

    final topInset = _edgeInset(bySide['Top']!, horizontal: true);
    final bottomInset = _edgeInset(bySide['Bottom']!, horizontal: true);
    final leftInset = _edgeInset(bySide['Left']!, horizontal: false);
    final rightInset = _edgeInset(bySide['Right']!, horizontal: false);

    Widget edge(String side) {
      final indexes = bySide[side]!;
      final count = indexes.length;
      if (count == 0) return const SizedBox.shrink();
      final horizontal = side == 'Top' || side == 'Bottom';
      // For two items, Expanded/Spacer/Expanded gives left+right or
      // top+bottom. For three, all three slots are occupied.
      final row = count == 1
          ? Center(child: itemFor(indexes.first))
          : count == 2
              ? Row(children: [Expanded(child: Center(child: itemFor(indexes[0]))), const Spacer(), Expanded(child: Center(child: itemFor(indexes[1])))])
              : Row(children: [Expanded(child: Center(child: itemFor(indexes[0]))), Expanded(child: Center(child: itemFor(indexes[1]))), Expanded(child: Center(child: itemFor(indexes[2])))]);
      final column = count == 1
          ? Center(child: itemFor(indexes.first))
          : count == 2
              ? Column(children: [Expanded(child: Center(child: itemFor(indexes[0]))), const Spacer(), Expanded(child: Center(child: itemFor(indexes[1])))])
              : Column(children: [Expanded(child: Center(child: itemFor(indexes[0]))), Expanded(child: Center(child: itemFor(indexes[1]))), Expanded(child: Center(child: itemFor(indexes[2])))]);
      return horizontal ? row : column;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset, left: leftInset, right: rightInset),
          child: child,
        ),
        if (bySide['Top']!.isNotEmpty) Positioned(top: 0, left: 0, right: 0, height: topInset, child: edge('Top')),
        if (bySide['Bottom']!.isNotEmpty) Positioned(bottom: 0, left: 0, right: 0, height: bottomInset, child: edge('Bottom')),
        if (bySide['Left']!.isNotEmpty) Positioned(top: 0, bottom: 0, left: 0, width: leftInset, child: edge('Left')),
        if (bySide['Right']!.isNotEmpty) Positioned(top: 0, bottom: 0, right: 0, width: rightInset, child: edge('Right')),
        // A Floating navbar remains floating over Home. It does not consume an
        // edge, so Storage/Live Sports can still use any side.
        if (navbarPosition == 'Floating')
          Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: Center(child: navbar))),
      ],
    );
  }

  double _edgeInset(List<int> indexes, {required bool horizontal}) {
    if (indexes.isEmpty) return 0;
    final hasNavbar = indexes.contains(0);
    final hasSports = indexes.contains(2);
    if (horizontal) {
      // Navbar ~84px, Storage ~76px, Sports ~235px. Add enough room for all
      // participants on the edge; the slot distribution is handled separately.
      var size = 0.0;
      if (hasNavbar) size = 84;
      if (indexes.contains(1)) size = size < 76 ? 76 : size;
      if (hasSports) size = size < 235 ? 235 : size;
      return size;
    }
    var size = 0.0;
    if (hasNavbar) size = 104;
    if (indexes.contains(1)) size = size < 230 ? 230 : size;
    if (hasSports) size = size < 325 ? 325 : size;
    return size;
  }
}

class MusicStorageCount {
  static double get value => MusicLibraryStore.instance.tracks.length.toDouble();
}
