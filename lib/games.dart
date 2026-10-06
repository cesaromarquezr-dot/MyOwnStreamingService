import 'package:flutter/material.dart';

import 'app_core.dart';
import 'core/models/game_catalog.dart';
import 'localization.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameCategory? _category;
  String _search = '';
  final _searchController = TextEditingController();
  Map<String, GameRating> _ratings = const {};
  bool _loadingRatings = true;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    try {
      final ratings = await AppController.instance.backendApi.getGameRatings(profileId: AppController.instance.currentProfile?.id ?? '');
      if (!mounted) return;
      setState(() {
        _ratings = {
          for (final row in ratings)
            GameRating.fromJson(row).gameId: GameRating.fromJson(row),
        };
        _loadingRatings = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRatings = false);
    }
  }

  String _categoryLabel(GameCategory category) => switch (category) {
        GameCategory.board => 'Board',
        GameCategory.card => 'Cards',
        GameCategory.casinoPlayMoney => 'Poker & Casino',
        GameCategory.puzzle => 'Puzzles',
        GameCategory.arcade => 'Arcade',
        GameCategory.dominoes => 'Dominoes',
        GameCategory.tile => 'Tiles',
        GameCategory.word => 'Word',
      };

  IconData _icon(GameCategory category) => switch (category) {
        GameCategory.board => Icons.grid_3x3,
        GameCategory.card => Icons.style_rounded,
        GameCategory.casinoPlayMoney => Icons.casino_outlined,
        GameCategory.puzzle => Icons.extension_outlined,
        GameCategory.arcade => Icons.sports_esports_outlined,
        GameCategory.dominoes => Icons.view_week_outlined,
        GameCategory.tile => Icons.apps_outlined,
        GameCategory.word => Icons.abc_rounded,
      };

  Future<void> _openGame(GameDefinition game) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameLaunchScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var games = GameCatalog.definitions.toList();
    final profile = AppController.instance.currentProfile;
    final childLike = profile?.governance.contentLevel.name == 'littleKids' ||
        profile?.governance.contentLevel.name == 'kids' ||
        profile?.governance.contentLevel.name == 'olderKids';
    if (childLike) {
      games = games.where((game) => !game.playMoneyOnly).toList();
    }
    if (_category != null) games = games.where((g) => g.category == _category).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      games = games.where((g) => g.name.toLowerCase().contains(q) || g.aliases.any((a) => a.toLowerCase().contains(q))).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Games'),
        actions: [
          IconButton(
            tooltip: 'Daily challenges',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyGamesScreen())),
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UniversalText('Play with friends, AI, or ranked matchmaking.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const UniversalText('Competitive ratings are separate for each game. Casino-style games use play-money architecture only.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search games', suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.clear))),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                const SizedBox(width: 8),
                for (final category in GameCategory.values) ...[
                  FilterChip(label: Text(_categoryLabel(category)), selected: _category == category, onSelected: (_) => setState(() => _category = category)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 4 : MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (_, index) {
              final game = games[index];
              final rating = _ratings[game.id];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openGame(game),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(_icon(game.category)), const Spacer(), if (game.playMoneyOnly) const Chip(label: Text('PLAY MONEY'))]),
                        const Spacer(),
                        Text(game.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${game.minPlayers}-${game.maxPlayers} players', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        if (rating != null)
                          Text('Rating ${rating.rating}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (games.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: UniversalText('No games matched your search.'))),
          if (!_loadingRatings && _ratings.isNotEmpty) ...[
            const SizedBox(height: 18),
            const UniversalText('Your ratings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ..._ratings.values.take(6).map((rating) => ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(GameCatalog.instance.byId(rating.gameId).name),
                  subtitle: Text('${rating.wins} wins • ${rating.losses} losses • ${rating.gamesPlayed} games'),
                  trailing: Text(rating.rating.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                )),
          ],
        ],
      ),
    );
  }
}

class GameLaunchScreen extends StatefulWidget {
  final GameDefinition game;
  const GameLaunchScreen({super.key, required this.game});

  @override
  State<GameLaunchScreen> createState() => _GameLaunchScreenState();
}

class _GameLaunchScreenState extends State<GameLaunchScreen> {
  bool _busy = false;

  Future<void> _createMatch(String mode) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final match = await AppController.instance.backendApi.createGameMatch(profileId: AppController.instance.currentProfile?.id ?? '', gameId: widget.game.id, mode: mode);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameMatchScreen(game: widget.game, match: match)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(game.description.isEmpty ? 'Choose how you want to play.' : game.description, style: const TextStyle(color: Colors.white60)),
            if (game.playMoneyOnly) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Play-money only. No cash wagering is enabled by this game framework.', style: TextStyle(color: Colors.amber))),
          ]))),
          const SizedBox(height: 14),
          if (game.minPlayers == 1) FilledButton.icon(onPressed: _busy ? null : () => _createMatch('solo'), icon: const Icon(Icons.person_outline), label: const Text('Play Solo')),
          if (game.supportsAi) ...[
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _busy ? null : () => _createMatch('ai'), icon: const Icon(Icons.smart_toy_outlined), label: const Text('Play AI')),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _busy ? null : () => _createMatch('friend'), icon: const Icon(Icons.people_outline), label: const Text('Play Friend / Private Room')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _busy ? null : () => _createMatch('casual'), icon: const Icon(Icons.sports_esports_outlined), label: const Text('Casual Matchmaking')),
          if (game.supportsRanked) ...[
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _busy ? null : () => _createMatch('ranked'), icon: const Icon(Icons.emoji_events_outlined), label: const Text('Ranked Match')),
          ],
        ],
      ),
    );
  }
}

class GameMatchScreen extends StatelessWidget {
  final GameDefinition game;
  final Map<String, dynamic> match;

  const GameMatchScreen({super.key, required this.game, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.games_rounded, size: 58),
                const SizedBox(height: 14),
                Text('${game.name} match created', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Match ${match['id'] ?? ''} is ready for the game engine.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                const Text('The platform foundation now handles players, ratings, friends/AI/ranked modes, and cross-server match identity. Individual game boards can plug into this authoritative match.', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyGamesScreen extends StatelessWidget {
  const DailyGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final daily = GameCatalog.definitions.where((game) => game.supportsDaily).toList();
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Daily Challenges')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: daily.length,
        itemBuilder: (_, index) {
          final game = daily[index];
          return Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.today_rounded)),
            title: Text(game.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('One official daily puzzle, plus practice mode.'),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameLaunchScreen(game: game))),
          ));
        },
      ),
    );
  }
}
