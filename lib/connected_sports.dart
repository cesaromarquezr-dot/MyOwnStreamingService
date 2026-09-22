// FILE: `lib/connected_sports.dart`.
// Purpose: Connected Sports Services hub. The app stores only provider
// preference selections here; provider credentials are never collected or
// persisted. Selecting a provider enables its sports data in the app but does
// not authenticate the user with that provider.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_core.dart';
import 'localization.dart';

class SportsProvider {
  final String id;
  final String name;
  final String description;
  final String url;
  final IconData icon;

  const SportsProvider(
    this.id,
    this.name,
    this.description,
    this.url,
    this.icon,
  );
}

const connectedSportsProviders = <SportsProvider>[
  // NFL+ is the current U.S. NFL subscription product.
  SportsProvider(
    'nfl_plus',
    'NFL+',
    'U.S. NFL subscription service for live and on-demand NFL content.',
    'https://www.nfl.com/plus/',
    Icons.sports_football_rounded,
  ),

  // NFL+ Premium is the higher NFL+ tier with additional features such as
  // RedZone/replays.
  SportsProvider(
    'nfl_plus_premium',
    'NFL+ Premium',
    'U.S. premium NFL+ tier with additional NFL content and features.',
    'https://www.nfl.com/plus/',
    Icons.workspace_premium_rounded,
  ),

  // Outside the U.S., NFL Game Pass is delivered internationally through
  // DAZN. Availability and features depend on region.
  SportsProvider(
    'nfl_game_pass_intl',
    'NFL Game Pass International',
    'International NFL Game Pass delivered through DAZN; availability and '
        'features depend on region.',
    'https://www.dazn.com/',
    Icons.public_rounded,
  ),

  SportsProvider(
    'espn',
    'ESPN+',
    'ESPN live events and sports information through the provider experience.',
    'https://www.espn.com/watch/',
    Icons.sports_score_rounded,
  ),

  SportsProvider(
    'mlb',
    'MLB.TV',
    'MLB games, scores, teams and league information.',
    'https://www.mlb.com/live-stream-games/',
    Icons.sports_baseball_rounded,
  ),

  SportsProvider(
    'nba',
    'NBA League Pass',
    'NBA games, scores, teams and player information.',
    'https://www.nba.com/watch/league-pass-stream',
    Icons.sports_basketball_rounded,
  ),

  SportsProvider(
    'nhl',
    'NHL',
    'NHL games, scores, teams and player information.',
    'https://www.nhl.com/plus',
    Icons.sports_hockey_rounded,
  ),
];

class ConnectedSportsHubScreen extends StatefulWidget {
  const ConnectedSportsHubScreen({super.key});

  @override
  State<ConnectedSportsHubScreen> createState() =>
      _ConnectedSportsHubScreenState();
}

class _ConnectedSportsHubScreenState extends State<ConnectedSportsHubScreen> {
  Set<String> enabledProviders = <String>{};

  List<Map<String, dynamic>> live = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> upcoming = <Map<String, dynamic>>[];

  bool loading = true;

  String get _prefsKey =>
      'connected_sports_${AppController.instance.currentProfile?.id ?? 'default'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? <String>[];

    if (mounted) {
      setState(() {
        enabledProviders = saved.toSet();
      });
    }

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
      // Provider preference cards remain usable even if the scoreboard feed
      // is temporarily unavailable.
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<void> _toggle(SportsProvider provider) async {
    final next = Set<String>.from(enabledProviders);

    if (next.contains(provider.id)) {
      next.remove(provider.id);
    } else {
      next.add(provider.id);
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _prefsKey,
      next.toList()..sort(),
    );

    if (mounted) {
      setState(() {
        enabledProviders = next;
      });
    }
  }

  Future<void> _openProvider(SportsProvider provider) async {
    final uri = Uri.parse(provider.url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const UniversalText('Connected Sports'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: tr('Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    size: 34,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: UniversalText(
                      'Enable the sports services you already use. Your app '
                      'can then surface scores, games, teams, players, '
                      'schedules and live status in the same interface. '
                      'Enabling a service here does not sign you into that '
                      'provider.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const UniversalText(
              'SPORTS SERVICES',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 10),
            for (final provider in connectedSportsProviders)
              _providerCard(provider),
            const SizedBox(height: 20),
            _gamesSection(
              'LIVE NOW',
              live,
              true,
            ),
            const SizedBox(height: 20),
            _gamesSection(
              'UPCOMING',
              upcoming,
              false,
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            const SizedBox(height: 12),
            const UniversalText(
              'Playback remains with the authorized sports provider. This app '
              'does not copy or redistribute provider video streams.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(SportsProvider provider) {
    final isEnabled = enabledProviders.contains(provider.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Icon(provider.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Switch(
                  value: isEnabled,
                  onChanged: (_) => _toggle(provider),
                ),
                Text(
                  isEnabled ? 'Enabled' : 'Enable',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => _openProvider(provider),
              tooltip: tr('Open provider'),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gamesSection(
    String title,
    List<Map<String, dynamic>> games,
    bool liveMode,
  ) {
    final visible = games.where(_matchesEnabledProvider).take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                enabledProviders.isEmpty
                    ? 'Enable a sports service above to personalize this section.'
                    : 'No ${liveMode ? 'live' : 'upcoming'} games are available '
                        'for the enabled services right now.',
              ),
            ),
          ),
        for (final game in visible)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                liveMode
                    ? Icons.circle
                    : Icons.schedule_rounded,
                color: liveMode ? Colors.redAccent : null,
              ),
              title: UniversalText(
                '${game['awayTeam'] ?? game['away'] ?? 'Away'}  vs  '
                '${game['homeTeam'] ?? game['home'] ?? 'Home'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                [
                  if (game['status'] != null)
                    game['status'].toString(),
                  if (game['score'] != null)
                    game['score'].toString(),
                  if (game['period'] != null)
                    game['period'].toString(),
                  if (game['startTime'] != null)
                    game['startTime'].toString(),
                ].join(' • '),
              ),
            ),
          ),
      ],
    );
  }

  bool _matchesEnabledProvider(Map<String, dynamic> game) {
    if (enabledProviders.isEmpty) {
      return false;
    }

    final league = (game['league'] ?? game['competition'] ?? '')
        .toString()
        .toLowerCase();

    final sport = (game['sport'] ?? '')
        .toString()
        .toLowerCase();

    final provider = (game['provider'] ?? game['source'] ?? '')
        .toString()
        .toLowerCase();

    final isNfl = league.contains('nfl') ||
        sport.contains('football') ||
        provider.contains('nfl');

    final isNba = league.contains('nba') ||
        sport.contains('basketball') ||
        provider.contains('nba');

    final isMlb = league.contains('mlb') ||
        sport.contains('baseball') ||
        provider.contains('mlb');

    final isNhl = league.contains('nhl') ||
        sport.contains('hockey') ||
        provider.contains('nhl');

    final isEspn =
        provider.contains('espn') ||
        game['espn'] == true;

    return enabledProviders.any(
      (id) {
        switch (id) {
          case 'nfl_plus':
          case 'nfl_plus_premium':
          case 'nfl_game_pass_intl':
            return isNfl;

          case 'nba':
            return isNba;

          case 'mlb':
            return isMlb;

          case 'nhl':
            return isNhl;

          case 'espn':
            return isEspn;

          default:
            return false;
        }
      },
    );
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
          title: const UniversalText(
            'Connected Sports',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const UniversalText(
            'Scores, live status, teams and schedules from your enabled '
            'sports services.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ConnectedSportsHubScreen(),
            ),
          ),
        ),
      );
}