// FILE: `lib/connected_sports.dart`.
// Purpose: Connected Sports Services hub. The app stores only provider connection
// preferences here; provider credentials are never collected or persisted.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';

class SportsProvider {
  final String id;
  final String name;
  final String description;
  final String url;
  final IconData icon;
  const SportsProvider(this.id, this.name, this.description, this.url, this.icon);
}

const connectedSportsProviders = <SportsProvider>[
  // NFL+ is the current U.S. NFL subscription product.
  SportsProvider('nfl_plus', 'NFL+', 'U.S. NFL subscription service for live and on-demand NFL content.', 'https://www.nfl.com/plus/', Icons.sports_football_rounded),
  // NFL+ Premium is the higher NFL+ tier with additional features such as RedZone/replays.
  SportsProvider('nfl_plus_premium', 'NFL+ Premium', 'U.S. premium NFL+ tier with additional NFL content and features.', 'https://www.nfl.com/plus/', Icons.workspace_premium_rounded),
  // Outside the U.S., NFL Game Pass is delivered internationally through DAZN.
  SportsProvider('nfl_game_pass_intl', 'NFL Game Pass International', 'International NFL Game Pass delivered through DAZN; availability and features depend on region.', 'https://www.dazn.com/', Icons.public_rounded),
  SportsProvider('espn', 'ESPN+', 'ESPN live events and sports information through the provider experience.', 'https://www.espn.com/watch/', Icons.sports_score_rounded),
  SportsProvider('mlb', 'MLB.TV', 'MLB games, scores, teams and league information.', 'https://www.mlb.com/live-stream-games/', Icons.sports_baseball_rounded),
  SportsProvider('nba', 'NBA League Pass', 'NBA games, scores, teams and player information.', 'https://www.nba.com/watch/league-pass-stream', Icons.sports_basketball_rounded),
  SportsProvider('nhl', 'NHL', 'NHL games, scores, teams and player information.', 'https://www.nhl.com/plus', Icons.sports_hockey_rounded),
];

class ConnectedSportsHubScreen extends StatefulWidget {
  const ConnectedSportsHubScreen({super.key});
  @override
  State<ConnectedSportsHubScreen> createState() => _ConnectedSportsHubScreenState();
}

class _ConnectedSportsHubScreenState extends State<ConnectedSportsHubScreen> {
  Set<String> connected = <String>{};
  List<Map<String, dynamic>> live = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> upcoming = <Map<String, dynamic>>[];
  bool loading = true;

  String get _prefsKey => 'connected_sports_${AppController.instance.currentProfile?.id ?? 'default'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? <String>[];
    if (mounted) setState(() => connected = saved.toSet());
    try {
      final api = AppController.instance.backendApi;
      final liveData = await api.getLiveSports();
      final upcomingData = await api.getUpcomingSports(days: 7);
      if (!mounted) return;
      setState(() {
        live = _maps(liveData['games']);
        upcoming = _maps(upcomingData['games']);
      });
    } catch (_) {
      // Connection cards remain usable even if the scoreboard feed is offline.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _toggle(SportsProvider provider) async {
    final next = Set<String>.from(connected);
    if (next.contains(provider.id)) {
      next.remove(provider.id);
    } else {
      next.add(provider.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next.toList()..sort());
    if (mounted) setState(() => connected = next);
  }

  Future<void> _openProvider(SportsProvider provider) async {
    await launchUrl(Uri.parse(provider.url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Sports'),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(22)),
              child: const Row(children: [
                Icon(Icons.hub_rounded, size: 34),
                SizedBox(width: 12),
                Expanded(child: Text('Connect the sports services you already use. Your app can then surface scores, games, teams, players, schedules and live status in the same interface.', style: TextStyle(color: Colors.white70, height: 1.4))),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('CONNECTED SERVICES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, color: Colors.white54)),
            const SizedBox(height: 10),
            for (final provider in connectedSportsProviders) _providerCard(provider),
            const SizedBox(height: 20),
            _gamesSection('LIVE NOW', live, true),
            const SizedBox(height: 20),
            _gamesSection('UPCOMING', upcoming, false),
            if (loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
            const SizedBox(height: 12),
            const Text('Playback remains with the authorized sports provider. This app does not copy or redistribute provider video streams.', style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(SportsProvider provider) {
    final isConnected = connected.contains(provider.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(radius: 24, child: Icon(provider.icon)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(provider.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(provider.description, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
          ])),
          const SizedBox(width: 8),
          Column(children: [
            Switch(value: isConnected, onChanged: (_) => _toggle(provider)),
            Text(isConnected ? 'Connected' : 'Connect', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
          IconButton(onPressed: () => _openProvider(provider), tooltip: 'Open provider', icon: const Icon(Icons.open_in_new_rounded)),
        ]),
      ),
    );
  }

  Widget _gamesSection(String title, List<Map<String, dynamic>> games, bool liveMode) {
    final visible = games.where((game) {
      if (connected.isEmpty) return false;
      final league = (game['league'] ?? game['competition'] ?? '').toString().toLowerCase();
      final sport = (game['sport'] ?? '').toString().toLowerCase();
      return connected.any((id) =>
          ((id == 'nfl_plus' || id == 'nfl_plus_premium' || id == 'nfl_game_pass_intl') && (league.contains('nfl') || sport.contains('football'))) ||
          (id == 'nba' && (league.contains('nba') || sport.contains('basketball'))) ||
          (id == 'mlb' && (league.contains('mlb') || sport.contains('baseball'))) ||
          (id == 'nhl' && (league.contains('nhl') || sport.contains('hockey'))) ||
          id == 'espn');
    }).take(12).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, color: Colors.white54)),
      const SizedBox(height: 10),
      if (visible.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(connected.isEmpty ? 'Connect a sports service above to personalize this section.' : 'No ${liveMode ? 'live' : 'upcoming'} games are available for the connected services right now.'))),
      for (final game in visible) Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(liveMode ? Icons.circle : Icons.schedule_rounded, color: liveMode ? Colors.redAccent : null),
          title: Text('${game['awayTeam'] ?? game['away'] ?? 'Away'}  vs  ${game['homeTeam'] ?? game['home'] ?? 'Home'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([if (game['status'] != null) game['status'].toString(), if (game['score'] != null) game['score'].toString(), if (game['period'] != null) game['period'].toString(), if (game['startTime'] != null) game['startTime'].toString()].join(' • ')),
        ),
      ),
    ]);
  }
}

/// Compact Home widget for the customizable Home Screen Builder.
class ConnectedSportsHomeWidget extends StatelessWidget {
  const ConnectedSportsHomeWidget({super.key});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: ListTile(
          leading: const Icon(Icons.sports_rounded),
          title: const Text('Connected Sports', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('Scores, live status, teams and schedules from your connected services.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectedSportsHubScreen())),
        ),
      );
}
