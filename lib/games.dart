import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_core.dart';
import 'core/models/game_catalog.dart';
import 'localization.dart';
import 'responsive.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameCategory? _category;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, GameRating> _ratings = const <String, GameRating>{};
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
      final ratings = await AppController.instance.backendApi.getGameRatings(
        profileId: AppController.instance.currentProfile?.id ?? '',
      );
      final parsed = <String, GameRating>{};
      for (final row in ratings) {
        final rating = GameRating.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (rating.gameId.isNotEmpty) {
          parsed[rating.gameId] = rating;
        }
      }
      if (!mounted) return;
      setState(() {
        _ratings = parsed;
        _loadingRatings = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRatings = false);
      }
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
        GameCategory.trivia => 'Trivia',
        GameCategory.party => 'Party',
        GameCategory.music => 'Music',
        GameCategory.movieTv => 'Movie / TV',
        GameCategory.racing => 'Racing',
        GameCategory.danceRhythm => 'Dance / Rhythm',
        GameCategory.fighting => 'Fighting',
        GameCategory.tournament => 'Tournaments',
        GameCategory.sports => 'Sports',
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
        GameCategory.trivia => Icons.quiz_rounded,
        GameCategory.party => Icons.celebration_rounded,
        GameCategory.music => Icons.music_note_rounded,
        GameCategory.movieTv => Icons.movie_rounded,
        GameCategory.racing => Icons.sports_motorsports_rounded,
        GameCategory.danceRhythm => Icons.moving_rounded,
        GameCategory.fighting => Icons.sports_mma_rounded,
        GameCategory.tournament => Icons.emoji_events_rounded,
        GameCategory.sports => Icons.sports_tennis_rounded,
      };

  Future<void> _openGame(GameDefinition game) async {
    if (!game.isPlayable) {
      final platformText = game.platformScope == GamePlatformScope.consolePcOnly
          ? 'Available only on TV/console/PC builds (PS5, Xbox Series X|S, Switch 2, and PC). '
          : 'Designed for all device types with a screen. ';
      final mediaText = game.usesServerMedia
          ? 'This game is designed to reference media IDs and metadata already stored on your server; it does not duplicate the source media. '
          : '';
      final motionText = game.supportsPhoneMotionController
          ? 'The planned implementation will reuse the shared phone motion-controller, pairing, calibration, and latency-compensation layer. '
          : '';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(game.name),
          content: SingleChildScrollView(
            child: Text(
              '${game.description.isEmpty ? 'This game is included in the expanded catalog.' : game.description}\n\n'
              '$platformText$mediaText$motionText\n'
              'Status: planned catalog entry. Its full gameplay engine and content pipeline still need to be implemented before it can be played.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/app/games/${game.id}'),
        builder: (_) => GameLaunchScreen(game: game),
      ),
    );
    if (mounted) {
      _loadRatings();
    }
  }

  @override
  Widget build(BuildContext context) {
    var games = GameCatalog.definitions.toList(growable: true);
    final profile = AppController.instance.currentProfile;
    final childLike = profile?.governance.contentLevel.name == 'littleKids' ||
        profile?.governance.contentLevel.name == 'kids' ||
        profile?.governance.contentLevel.name == 'olderKids';

    if (childLike) {
      games = games.where((game) => !game.playMoneyOnly).toList();
    }

    final targetPlatform = defaultTargetPlatform;
    final isDesktopPlatform = targetPlatform == TargetPlatform.windows ||
        targetPlatform == TargetPlatform.linux ||
        targetPlatform == TargetPlatform.macOS;
    final isLargeWebWindow = kIsWeb && MediaQuery.sizeOf(context).width >= 1024;
    final canShowConsolePcGames = isDesktopPlatform || isLargeWebWindow || context.isTv;
    if (!canShowConsolePcGames) {
      games = games
          .where((game) => game.platformScope != GamePlatformScope.consolePcOnly)
          .toList();
    }

    if (_category != null) {
      games = games
          .where((game) => game.category == _category)
          .toList();
    }

    if (_search.trim().isNotEmpty) {
      final query = _search.trim().toLowerCase();
      games = games
          .where(
            (game) =>
                game.name.toLowerCase().contains(query) ||
                game.aliases.any(
                  (alias) => alias.toLowerCase().contains(query),
                ),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Games'),
        actions: [
          IconButton(
            tooltip: 'Daily challenges',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DailyGamesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const UniversalText(
            'Board, card, puzzle, word, party, music, dance, racing, movie/TV, and tournament games.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const UniversalText(
            'Playable games launch their implemented rules engine. Expanded catalog entries are clearly marked Planned until their full game engine is ready. Music and movie/TV games are designed to reference your existing server library. Food & Delivery remains a separate feature.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search games',
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                const SizedBox(width: 8),
                for (final category in GameCategory.values) ...[
                  FilterChip(
                    label: Text(_categoryLabel(category)),
                    selected: _category == category,
                    onSelected: (_) {
                      setState(() => _category = category);
                    },
                  ),
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
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1100
                  ? 4
                  : MediaQuery.sizeOf(context).width >= 700
                      ? 3
                      : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
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
                        Row(
                          children: [
                            Icon(_icon(game.category)),
                            const Spacer(),
                            if (game.playMoneyOnly)
                              const Chip(label: Text('PLAY MONEY')),
                            if (!game.isPlayable)
                              const Chip(
                                label: Text('PLANNED'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          game.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${game.minPlayers}-${game.maxPlayers} players',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (game.platformScope == GamePlatformScope.consolePcOnly)
                          const Text(
                            'TV / console / PC only',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        if (rating != null)
                          Text(
                            'Rating ${rating.rating}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (games.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: UniversalText('No games matched your search.'),
              ),
            ),
          if (!_loadingRatings && _ratings.isNotEmpty) ...[
            const SizedBox(height: 18),
            const UniversalText(
              'Your ratings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ..._ratings.values.take(6).map(
                  (rating) => ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: Text(
                      GameCatalog.instance.byId(rating.gameId).name,
                    ),
                    subtitle: Text(
                      '${rating.wins} wins • ${rating.losses} losses • ${rating.gamesPlayed} games',
                    ),
                    trailing: Text(
                      rating.rating.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
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
  String _difficulty = 'medium';
  String _variant = 'standard';

  @override
  void initState() {
    super.initState();
    final variants = _GamePlayCatalog.variantsFor(widget.game.id);
    if (variants.isNotEmpty) {
      final preferred = switch (widget.game.id) {
        'sudoku' => 'classic_9x9',
        'jigsaw' => 'irregular_9x9',
        'spider' => 'one_suit',
        _ => variants.first.id,
      };
      _variant = variants.any((item) => item.id == preferred)
          ? preferred
          : variants.first.id;
    }
  }

  List<_GameVariantOption> get _variants =>
      _GamePlayCatalog.variantsFor(widget.game.id);

  String _difficultyLabel(String value) => switch (value) {
        'easy' => 'Easy',
        'medium' => 'Medium',
        'hard' => 'Hard',
        'expert' => 'Expert',
        'master' => 'Master',
        'grandmaster' => 'Grandmaster',
        'random' => 'Random',
        _ => value,
      };

  Future<void> _createMatch(String mode) async {
    if (_busy) return;

    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null || profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a profile before starting a game.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final match = <String, dynamic>{
        'id': 'local-${widget.game.id}-${DateTime.now().microsecondsSinceEpoch}',
        'gameId': widget.game.id,
        'profileId': profileId,
        'mode': mode,
        'status': 'created',
        'local': mode == 'solo' || mode == 'ai' || mode == 'friend',
        'difficulty': _difficulty,
        'variant': _variant,
      };

      if (match['local'] != true) {
        final response =
            await AppController.instance.backendApi.createGameMatch(
          profileId: profileId,
          gameId: widget.game.id,
          mode: mode,
          difficulty: _difficulty,
          variant: _variant,
        );
        final raw = response['match'];
        final serverMatch = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{
                'id': response['id'] ?? match['id'],
                'gameId': widget.game.id,
                'profileId': profileId,
                'mode': mode,
                'status': response['status'] ?? 'created',
                ...response,
              };
        serverMatch['difficulty'] = _difficulty;
        serverMatch['variant'] = _variant;
        match
          ..clear()
          ..addAll(serverMatch);
      }

      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: '/app/games/${widget.game.id}/match',
          ),
          builder: (_) => GameMatchScreen(
            game: widget.game,
            match: match,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modeButton({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    bool filled = false,
  }) {
    final onPressed = _busy ? null : () => _createMatch(mode);
    final child = Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: child,
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: child,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final variants = _variants;

    final diceCount = _GamePlayCatalog.diceCountFor(game.id);
    final usesCards = _GamePlayCatalog.usesCardsFor(game.id);

    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_esports_rounded, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          game.name,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    game.description.isEmpty
                        ? 'Choose the game type, difficulty, and how you want to play.'
                        : game.description,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('${game.minPlayers}-${game.maxPlayers} players')),
                      if (diceCount > 0)
                        Chip(
                          avatar: const Icon(Icons.casino_outlined, size: 18),
                          label: Text('$diceCount ${diceCount == 1 ? 'die' : 'dice'}'),
                        ),
                      if (usesCards)
                        const Chip(
                          avatar: Icon(Icons.style_rounded, size: 18),
                          label: Text('Cards'),
                        ),
                    ],
                  ),
                  if (game.playMoneyOnly)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Play-money only. No cash wagering is enabled by this game framework.',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Game options',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty',
              prefixIcon: Icon(Icons.speed_rounded),
            ),
            items: _GamePlayCatalog.difficulties
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_difficultyLabel(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: _busy
                ? null
                : (value) => setState(
                      () => _difficulty = value ?? 'medium',
                    ),
          ),
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  variants.any((v) => v.id == _variant) ? _variant : variants.first.id,
              decoration: const InputDecoration(
                labelText: 'Game type / variant',
                prefixIcon: Icon(Icons.grid_view_rounded),
              ),
              items: variants
                  .map(
                    (v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(v.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _busy
                  ? null
                  : (value) => setState(
                        () => _variant = value ?? variants.first.id,
                      ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                variants.firstWhere((v) => v.id == _variant).description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Choose how to play',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'The selected difficulty and game type are carried into the match and its rules engine.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          if (game.minPlayers == 1)
            _modeButton(
              mode: 'solo',
              title: 'Play Solo',
              subtitle: 'Start immediately on this device.',
              icon: Icons.person_outline_rounded,
              filled: true,
            ),
          if (game.supportsAi) ...[
            if (game.minPlayers == 1) const SizedBox(height: 10),
            _modeButton(
              mode: 'ai',
              title: 'Play with AI',
              subtitle: 'Play against the computer using the selected difficulty.',
              icon: Icons.smart_toy_outlined,
              filled: true,
            ),
          ],
          if (game.minPlayers > 1) ...[
            const SizedBox(height: 10),
            _modeButton(
              mode: 'friend',
              title: 'Play with a Friend',
              subtitle: 'Pass-and-play local match.',
              icon: Icons.people_outline_rounded,
            ),
            const SizedBox(height: 10),
            _modeButton(
              mode: 'casual',
              title: 'Play with Anyone Online',
              subtitle: 'Use online casual matchmaking.',
              icon: Icons.public_rounded,
            ),
          ],
          if (game.supportsRanked) ...[
            const SizedBox(height: 10),
            _modeButton(
              mode: 'ranked',
              title: 'Play Ranked',
              subtitle: 'Compete for your game rating.',
              icon: Icons.emoji_events_outlined,
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _GameVariantOption {
  final String id;
  final String name;
  final String description;

  const _GameVariantOption(this.id, this.name, this.description);

  factory _GameVariantOption.fromCatalog(GameVariantDefinition definition) =>
      _GameVariantOption(
        definition.id,
        definition.name,
        definition.description,
      );
}

class _GamePlayCatalog {
  static const difficulties = GameCatalog.difficultyLevels;

  static int diceCountFor(String gameId) =>
      GameCatalog.instance.byId(gameId).diceCount;

  static bool usesCardsFor(String gameId) =>
      GameCatalog.instance.byId(gameId).usesCards;

  static List<_GameVariantOption> variantsFor(String gameId) =>
      GameCatalog.variantDefinitions[gameId]
          ?.map(_GameVariantOption.fromCatalog)
          .toList(growable: false) ??
      const <_GameVariantOption>[];
}

class BoardThemeConfig {
  final Color light;
  final Color dark;
  final Color accent;
  final double boardSize;
  final PieceStyle pieceStyle;

  const BoardThemeConfig({
    this.light = const Color(0xFFF0D9B5),
    this.dark = const Color(0xFFB58863),
    this.accent = Colors.redAccent,
    this.boardSize = 520,
    this.pieceStyle = PieceStyle.circle,
  });

  BoardThemeConfig copyWith({
    Color? light,
    Color? dark,
    Color? accent,
    double? boardSize,
    PieceStyle? pieceStyle,
  }) {
    return BoardThemeConfig(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      accent: accent ?? this.accent,
      boardSize: boardSize ?? this.boardSize,
      pieceStyle: pieceStyle ?? this.pieceStyle,
    );
  }
}

enum PieceStyle {
  circle,
  star,
  diamond,
  crown,
}

class GameMatchScreen extends StatefulWidget {
  final GameDefinition game;
  final Map<String, dynamic> match;

  const GameMatchScreen({
    super.key,
    required this.game,
    required this.match,
  });

  @override
  State<GameMatchScreen> createState() => _GameMatchScreenState();
}

class _GameMatchScreenState extends State<GameMatchScreen> {
  BoardThemeConfig _theme = const BoardThemeConfig();
  bool _finishing = false;

  String _modeTitle(String mode) => switch (mode) {
        'solo' => 'Solo game',
        'ai' => 'Game against AI',
        'friend' => 'Private friend game',
        'casual' => 'Online casual game',
        'ranked' => 'Ranked game',
        _ => 'Game',
      };

  Future<void> _openBoardSettings() async {
    final result = await showModalBottomSheet<BoardThemeConfig>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      builder: (sheetContext) {
        var draft = _theme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize board',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose board colors, board size and your piece style.',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Board colors',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final colors in const [
                            [Color(0xFFF0D9B5), Color(0xFFB58863)],
                            [Color(0xFFE8E8E8), Color(0xFF4A4A4A)],
                            [Color(0xFFC7E6C5), Color(0xFF5D8C61)],
                            [Color(0xFFF7D6E0), Color(0xFFA65D73)],
                            [Color(0xFFD7D0FF), Color(0xFF665FAD)],
                          ])
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  draft = draft.copyWith(
                                    light: colors[0],
                                    dark: colors[1],
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 82,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [colors[0], colors[1]],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Accent',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (final color in const [
                            Colors.redAccent,
                            Colors.blueAccent,
                            Colors.greenAccent,
                            Colors.amber,
                            Colors.purpleAccent,
                            Colors.cyanAccent,
                          ])
                            GestureDetector(
                              onTap: () => setDialogState(
                                () => draft = draft.copyWith(accent: color),
                              ),
                              child: CircleAvatar(
                                backgroundColor: color,
                                radius: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Board size: ${draft.boardSize.round()} px',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Slider(
                        min: 280,
                        max: 680,
                        divisions: 20,
                        value: draft.boardSize,
                        onChanged: (value) {
                          setDialogState(() {
                            draft = draft.copyWith(boardSize: value);
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Piece style',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<PieceStyle>(
                        initialValue: draft.pieceStyle,
                        items: const [
                          DropdownMenuItem(
                            value: PieceStyle.circle,
                            child: Text('Classic circle'),
                          ),
                          DropdownMenuItem(
                            value: PieceStyle.star,
                            child: Text('Star'),
                          ),
                          DropdownMenuItem(
                            value: PieceStyle.diamond,
                            child: Text('Diamond'),
                          ),
                          DropdownMenuItem(
                            value: PieceStyle.crown,
                            child: Text('Crown'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            draft = draft.copyWith(pieceStyle: value);
                          });
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, draft),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() => _theme = result);
  }

  Future<void> _finishGame(String result) async {
    if (_finishing) return;
    _finishing = true;

    final profileId = AppController.instance.currentProfile?.id;
    if (profileId != null && profileId.isNotEmpty) {
      try {
        await AppController.instance.backendApi.submitGameResult(
          profileId: profileId,
          gameId: widget.game.id,
          mode: widget.match['mode']?.toString() ?? 'solo',
          result: result,
          opponentRating: 500,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(result == 'win' ? 'You won!' : result == 'draw' ? 'Draw' : 'Game over'),
        content: Text(
          result == 'win'
              ? 'The game result has been recorded for this profile.'
              : result == 'draw'
                  ? 'The game was recorded as a draw.'
                  : 'The game result has been recorded.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _boardForMode() {
    final mode = widget.match['mode']?.toString() ?? 'casual';
    final status = widget.match['status']?.toString() ?? 'created';

    if ((mode == 'ranked' || mode == 'casual') && status == 'queued') {
      return _MatchmakingQueueCard(
        game: widget.game,
        match: widget.match,
      );
    }

    final difficulty = widget.match['difficulty']?.toString() ?? 'medium';
    final variant = widget.match['variant']?.toString() ?? 'standard';

    if (widget.game.id == 'ludo') {
      return LudoGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'chess') {
      return ChessGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'snakes_ladders') {
      return SnakesLaddersGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'monopoly') {
      return MonopolyGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'backgammon') {
      return BackgammonGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'sorry') {
      return SorryGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    return PracticeGameBoard(
      game: widget.game,
      theme: _theme,
      mode: mode,
      difficulty: difficulty,
      variant: variant,
      onFinished: _finishGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.match['mode']?.toString() ?? 'casual';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name),
        actions: [
          IconButton(
            tooltip: 'Customize board',
            onPressed: _openBoardSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _modeTitle(mode),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (mode == 'ai')
                const Chip(
                  avatar: Icon(Icons.smart_toy_outlined),
                  label: Text('AI'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _boardForMode(),
        ],
      ),
    );
  }
}

class _MatchmakingQueueCard extends StatelessWidget {
  final GameDefinition game;
  final Map<String, dynamic> match;

  const _MatchmakingQueueCard({
    required this.game,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 60),
            const SizedBox(height: 14),
            Text(
              'Looking for an opponent for ${game.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This match is in matchmaking. The game board opens automatically once the backend reports a matched opponent.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            SelectableText(
              'Queue ${match['id'] ?? ''}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedDiceDisplay extends StatelessWidget {
  final List<int> values;
  final bool rolling;
  final double size;

  const AnimatedDiceDisplay({
    super.key,
    required this.values,
    this.rolling = false,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final safeValues = values.isEmpty ? const [1] : values;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < safeValues.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedRotation(
            duration: const Duration(milliseconds: 110),
            turns: rolling ? .22 : 0,
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 110),
              scale: rolling ? .92 : 1,
              child: _DieFace(
                value: safeValues[i].clamp(1, 6).toInt(),
                size: size,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DieFace extends StatelessWidget {
  final int value;
  final double size;

  const _DieFace({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .18),
        border: Border.all(color: Colors.black.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DiePipPainter(value),
      ),
    );
  }
}

class _DiePipPainter extends CustomPainter {
  final int value;

  _DiePipPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final spots = <Offset>[];
    final left = size.width * .25;
    final mid = size.width * .5;
    final right = size.width * .75;
    final top = size.height * .25;
    final center = size.height * .5;
    final bottom = size.height * .75;

    switch (value) {
      case 1:
        spots.add(Offset(mid, center));
      case 2:
        spots.addAll([Offset(left, top), Offset(right, bottom)]);
      case 3:
        spots.addAll([Offset(left, top), Offset(mid, center), Offset(right, bottom)]);
      case 4:
        spots.addAll([
          Offset(left, top),
          Offset(right, top),
          Offset(left, bottom),
          Offset(right, bottom),
        ]);
      case 5:
        spots.addAll([
          Offset(left, top),
          Offset(right, top),
          Offset(mid, center),
          Offset(left, bottom),
          Offset(right, bottom),
        ]);
      case 6:
        spots.addAll([
          Offset(left, top),
          Offset(right, top),
          Offset(left, center),
          Offset(right, center),
          Offset(left, bottom),
          Offset(right, bottom),
        ]);
    }

    for (final spot in spots) {
      canvas.drawCircle(spot, size.width * .075, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiePipPainter oldDelegate) =>
      oldDelegate.value != value;
}

class LudoGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const LudoGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<LudoGameBoard> createState() => _LudoGameBoardState();
}

class _LudoGameBoardState extends State<LudoGameBoard> {
  final Random _random = Random();
  final List<List<int>> _pieces = [
    [-1, -1, -1, -1],
    [-1, -1, -1, -1],
  ];

  int _currentPlayer = 0;
  int _dice = 0;
  bool _rolling = false;
  int? _winner;

  bool get _aiMode => widget.mode == 'ai';

  static const List<Color> _playerColors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
  ];

  static const List<String> _playerNames = [
    'You',
    'AI / Player 2',
  ];

  bool _canMove(int player, int piece) {
    if (_dice <= 0) return false;
    final value = _pieces[player][piece];
    if (value == -1) return _dice == 6;
    return value + _dice <= 56;
  }

  List<int> _legalPieces(int player) {
    final result = <int>[];
    for (var i = 0; i < 4; i++) {
      if (_canMove(player, i)) result.add(i);
    }
    return result;
  }

  Future<int> _animateDiceRoll() async {
    setState(() => _rolling = true);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return _dice;
      setState(() => _dice = 1 + _random.nextInt(6));
    }
    if (mounted) setState(() => _rolling = false);
    return _dice;
  }

  void _rollDice() async {
    if (_rolling || _winner != null || _currentPlayer != 0) return;
    await _animateDiceRoll();
    if (mounted) _afterRoll();
  }

  void _afterRoll() {
    if (_winner != null) return;
    final legal = _legalPieces(_currentPlayer);
    if (legal.isEmpty) {
      final keepTurn = _dice == 6;
      setState(() {
        _dice = 0;
        if (!keepTurn) _currentPlayer = (_currentPlayer + 1) % 2;
      });
      if (_currentPlayer == 1 && _aiMode) {
        _runAiTurn();
      }
      return;
    }

    if (_currentPlayer == 1 && _aiMode) {
      final piece = legal.first;
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (!mounted || _winner != null) return;
        _movePiece(piece);
      });
    }
  }

  void _movePiece(int piece) {
    if (_winner != null || !_canMove(_currentPlayer, piece)) return;

    final old = _pieces[_currentPlayer][piece];
    final rolledSix = _dice == 6;
    final next = old == -1 ? 0 : old + _dice;

    setState(() {
      _pieces[_currentPlayer][piece] = next;
      _dice = 0;
    });

    _captureOpponents(_currentPlayer, next);

    if (_pieces[_currentPlayer].every((value) => value == 56)) {
      setState(() => _winner = _currentPlayer);
      widget.onFinished(
        _currentPlayer == 0 ? 'win' : 'loss',
      );
      return;
    }

    if (!rolledSix) {
      setState(() {
        _currentPlayer = (_currentPlayer + 1) % 2;
      });
    }

    if (_currentPlayer == 1 && _aiMode) {
      _runAiTurn();
    }
  }

  void _captureOpponents(int player, int step) {
    if (step < 0 || step >= 52) return;

    final globalPosition = (player * 26 + step) % 52;
    if (globalPosition == 0 ||
        globalPosition == 13 ||
        globalPosition == 26 ||
        globalPosition == 39) {
      return;
    }

    final opponent = player == 0 ? 1 : 0;
    for (var piece = 0; piece < 4; piece++) {
      final opponentStep = _pieces[opponent][piece];
      if (opponentStep < 0 || opponentStep >= 52) continue;
      final opponentGlobal = (opponent * 26 + opponentStep) % 52;
      if (opponentGlobal == globalPosition) {
        setState(() {
          _pieces[opponent][piece] = -1;
        });
      }
    }
  }

  void _runAiTurn() {
    if (_winner != null || !_aiMode || _currentPlayer != 1) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted || _winner != null || _currentPlayer != 1) return;
      await _animateDiceRoll();
      if (mounted) _afterAiRoll();
    });
  }

  void _afterAiRoll() {
    if (!mounted || _winner != null) return;
    final legal = _legalPieces(1);
    if (legal.isEmpty) {
      final keepTurn = _dice == 6;
      setState(() {
        _dice = 0;
        if (!keepTurn) _currentPlayer = 0;
      });
      if (_currentPlayer == 1) {
        _runAiTurn();
      }
      return;
    }

    legal.sort((a, b) {
      final aStep = _pieces[1][a];
      final bStep = _pieces[1][b];
      return bStep.compareTo(aStep);
    });

    _movePiece(legal.first);
  }

  void _reset() {
    setState(() {
      for (final player in _pieces) {
        for (var i = 0; i < player.length; i++) {
          player[i] = -1;
        }
      }
      _currentPlayer = 0;
      _dice = 0;
      _winner = null;
    });
  }

  IconData _pieceIcon(PieceStyle style) => switch (style) {
        PieceStyle.circle => Icons.circle,
        PieceStyle.star => Icons.star,
        PieceStyle.diamond => Icons.diamond,
        PieceStyle.crown => Icons.workspace_premium,
      };

  Offset _pathPoint(int index) {
    final angle = -pi / 2 + (2 * pi * index / 52);
    const radius = 0.36;
    return Offset(
      0.5 + cos(angle) * radius,
      0.5 + sin(angle) * radius,
    );
  }

  Offset _piecePoint(int player, int piece) {
    final step = _pieces[player][piece];
    if (step < 0) {
      final home = player == 0
          ? const Offset(.18, .18)
          : const Offset(.82, .82);
      final slot = piece % 4;
      const positions = [
        Offset(-.055, -.055),
        Offset(.055, -.055),
        Offset(-.055, .055),
        Offset(.055, .055),
      ];
      return home + positions[slot];
    }

    if (step >= 52) {
      final finishStep = step - 51;
      final playerDirection = player == 0 ? -1.0 : 1.0;
      return Offset(
        0.5,
        0.5 + playerDirection * (0.18 - finishStep * 0.025),
      );
    }

    return _pathPoint((player * 26 + step) % 52);
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final boardSize = min<double>(widget.theme.boardSize, min<double>(maxWidth, 680.0));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _winner == null
                        ? '${_playerNames[_currentPlayer]} turn'
                        : '${_playerNames[_winner!]} won',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_dice > 0 || _rolling)
                  AnimatedDiceDisplay(
                    values: [_dice <= 0 ? 1 : _dice],
                    rolling: _rolling,
                    size: 50,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.theme.light,
                            widget.theme.dark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 52; i++)
                    _buildPathCell(boardSize, i),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: boardSize * .23,
                        height: boardSize * .23,
                        decoration: BoxDecoration(
                          color: widget.theme.accent.withValues(alpha: .2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.theme.accent.withValues(alpha: .7),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          size: 42,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  for (var player = 0; player < 2; player++)
                    for (var piece = 0; piece < 4; piece++)
                      _buildPiece(
                        boardSize,
                        player,
                        piece,
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _currentPlayer == 0 &&
                          _winner == null &&
                          !_rolling &&
                          _legalPieces(0).isEmpty
                      ? _rollDice
                      : (_currentPlayer == 0 &&
                              _winner == null &&
                              !_rolling &&
                              _dice == 0
                          ? _rollDice
                          : null),
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(_rolling ? 'Rolling…' : 'Roll dice'),
                ),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _dice == 0
                  ? 'Roll the dice. A 6 brings a home piece onto the board.'
                  : _legalPieces(_currentPlayer).isEmpty
                      ? 'No legal move.'
                      : 'Tap one of your highlighted pieces to move it.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathCell(double boardSize, int index) {
    final point = _pathPoint(index);
    final cellSize = boardSize * .055;
    final legal = _currentPlayer == 0 &&
        _dice > 0 &&
        _legalPieces(0).any(
          (piece) =>
              _pieces[0][piece] >= 0 &&
              _pieces[0][piece] < 52 &&
              ((26 * 0 + _pieces[0][piece]) % 52) == index,
        );

    return Positioned(
      left: point.dx * boardSize - cellSize / 2,
      top: point.dy * boardSize - cellSize / 2,
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: legal
              ? widget.theme.accent.withValues(alpha: .5)
              : Colors.white.withValues(alpha: .78),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: .18),
          ),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: max(7, boardSize * .014),
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPiece(
    double boardSize,
    int player,
    int piece,
  ) {
    final point = _piecePoint(player, piece);
    final pieceSize = boardSize * .07;
    final movable = _currentPlayer == player &&
        _dice > 0 &&
        _canMove(player, piece);

    return Positioned(
      left: point.dx * boardSize - pieceSize / 2,
      top: point.dy * boardSize - pieceSize / 2,
      width: pieceSize,
      height: pieceSize,
      child: GestureDetector(
        onTap: player == 0 ? () => _movePiece(piece) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _playerColors[player],
            shape: BoxShape.circle,
            border: Border.all(
              color: movable ? Colors.white : Colors.black.withValues(alpha: .35),
              width: movable ? 3 : 1.5,
            ),
            boxShadow: [
              if (movable)
                BoxShadow(
                  color: widget.theme.accent.withValues(alpha: .55),
                  blurRadius: 16,
                ),
            ],
          ),
          child: Icon(
            _pieceIcon(widget.theme.pieceStyle),
            color: Colors.white,
            size: pieceSize * .58,
          ),
        ),
      ),
    );
  }
}


class SnakesLaddersGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const SnakesLaddersGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<SnakesLaddersGameBoard> createState() => _SnakesLaddersGameBoardState();
}

class _SnakesLaddersGameBoardState extends State<SnakesLaddersGameBoard> {
  final Random _random = Random();
  int _you = 0;
  int _opponent = 0;
  int _current = 0;
  int _dice = 1;
  bool _rolling = false;
  bool _finished = false;
  Timer? _aiTimer;

  Map<int, int> get _jumps => widget.variant == 'short_64'
      ? const <int, int>{
          4: 15,
          9: 21,
          17: 7,
          22: 38,
          31: 13,
          35: 52,
          44: 26,
          49: 64,
          58: 42,
        }
      : const <int, int>{
          4: 14,
          9: 31,
          17: 7,
          20: 38,
          28: 84,
          40: 59,
          51: 67,
          54: 34,
          62: 19,
          63: 81,
          64: 60,
          71: 91,
          87: 24,
          93: 73,
          95: 75,
          99: 78,
        };

  int get _finish => widget.variant == 'short_64' ? 64 : 100;

  Future<void> _animateRoll({required VoidCallback after}) async {
    setState(() => _rolling = true);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() => _dice = 1 + _random.nextInt(6));
    }
    if (!mounted) return;
    setState(() => _rolling = false);
    after();
  }

  Future<void> _roll() async {
    if (_finished || _rolling || _current != 0) return;
    await _animateRoll(after: _moveCurrent);
  }

  void _moveCurrent() {
    if (_finished) return;
    setState(() {
      final candidate = _you + _dice;
      if (candidate <= _finish) {
        _you = _jumps[candidate] ?? candidate;
      }
    });
    _checkWinner(0);
  }

  void _checkWinner(int player) {
    final position = player == 0 ? _you : _opponent;
    if (position < _finish) {
      if (player == 0) {
        setState(() => _current = 1);
        _runAi();
      }
      return;
    }
    _finished = true;
    widget.onFinished(player == 0 ? 'win' : 'loss');
  }

  void _runAi() {
    if (_finished || widget.mode != 'ai') return;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || _finished || _current != 1) return;
      await _animateRoll(after: () {
        final candidate = _opponent + _dice;
        setState(() {
          if (candidate <= _finish) {
            _opponent = _jumps[candidate] ?? candidate;
          }
        });
        final pos = _opponent;
        if (pos >= _finish) {
          _finished = true;
          widget.onFinished('loss');
        } else {
          setState(() => _current = 0);
        }
      });
    });
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _finish == 64 ? 64 : 100;
    final cells = List<int>.generate(size, (i) => i + 1).reversed.toList();
    final columns = _finish == 64 ? 8 : 10;
    final boardSize = min<double>(
      widget.theme.boardSize,
      MediaQuery.sizeOf(context).width - 32,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _finished
                        ? 'Game finished'
                        : _current == 0
                            ? 'Your turn'
                            : 'AI / Player 2 turn',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                AnimatedDiceDisplay(values: [_dice], rolling: _rolling, size: 48),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                ),
                itemCount: cells.length,
                itemBuilder: (_, index) {
                  final number = cells[index];
                  final youHere = _you == number;
                  final opponentHere = _opponent == number;
                  final jump = _jumps[number];
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: number == _finish
                          ? widget.theme.accent.withValues(alpha: .26)
                          : Colors.white.withValues(alpha: .06),
                      border: Border.all(color: Colors.white.withValues(alpha: .10)),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4,
                          top: 3,
                          child: Text(
                            '$number',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (jump != null)
                          Positioned(
                            right: 4,
                            bottom: 3,
                            child: Icon(
                              jump > number ? Icons.north_east_rounded : Icons.south_west_rounded,
                              size: 16,
                              color: jump > number ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (youHere) const CircleAvatar(radius: 9, child: Icon(Icons.person, size: 12)),
                              if (youHere && opponentHere) const SizedBox(width: 2),
                              if (opponentHere) const CircleAvatar(radius: 9, child: Icon(Icons.smart_toy, size: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('You: $_you / $_finish • Player 2: $_opponent / $_finish', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _current == 0 && !_rolling && !_finished ? _roll : null,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(_rolling ? 'Rolling…' : 'Roll 1 die'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _you = 0;
                      _opponent = 0;
                      _current = 0;
                      _dice = 1;
                      _finished = false;
                    });
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MonopolyGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const MonopolyGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<MonopolyGameBoard> createState() => _MonopolyGameBoardState();
}

class _MonopolyGameBoardState extends State<MonopolyGameBoard> {
  final Random _random = Random();
  static const _names = [
    'GO', 'Mediterranean', 'Community Chest', 'Baltic', 'Income Tax', 'Reading Railroad',
    'Oriental', 'Chance', 'Vermont', 'Connecticut', 'Jail / Just Visiting', 'St. Charles',
    'Electric Company', 'States', 'Virginia', 'Pennsylvania RR', 'St. James', 'Community Chest',
    'Tennessee', 'New York', 'Free Parking', 'Kentucky', 'Chance', 'Indiana', 'Illinois',
    'B&O Railroad', 'Atlantic', 'Vermont Utility', 'Marvin Gardens', 'Go To Jail', 'Pacific',
    'North Carolina', 'Community Chest', 'Pennsylvania', 'Short Line', 'Chance', 'Park Place',
    'Luxury Tax', 'Boardwalk',
  ];

  late List<int> _positions;
  late List<int> _money;
  late List<int?> _owners;
  int _current = 0;
  List<int> _dice = const [1, 1];
  bool _rolling = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _positions = [0, 0];
    _money = [1500, 1500];
    _owners = List<int?>.filled(40, null);
    _current = 0;
    _dice = const [1, 1];
    _rolling = false;
    _finished = false;
  }

  bool _propertySpace(int index) => !{
        0, 2, 4, 5, 7, 10, 12, 15, 17, 20, 22, 25, 27, 28, 30, 33, 35, 36, 38,
      }.contains(index);

  int _price(int index) => widget.variant == 'short'
      ? 100 + (index % 8) * 40
      : 60 + (index % 10) * 20;

  Future<void> _rollAndMove() async {
    if (_rolling || _finished || _current != 0) return;
    setState(() => _rolling = true);
    for (var i = 0; i < 9; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 65));
      if (!mounted) return;
      setState(() {
        _dice = [1 + _random.nextInt(6), 1 + _random.nextInt(6)];
      });
    }
    if (!mounted) return;
    setState(() => _rolling = false);
    await _movePlayer(0);
    if (!_finished) {
      setState(() => _current = 1);
      _aiTurn();
    }
  }

  Future<void> _movePlayer(int player) async {
    final steps = _dice[0] + _dice[1];
    final old = _positions[player];
    final next = (old + steps) % 40;
    if (old + steps >= 40) {
      setState(() => _money[player] += 200);
    }
    setState(() => _positions[player] = next);
    _resolveSpace(player, next);
    if (_money[player] < 0) _finish(player == 0 ? 'loss' : 'win');
  }

  void _resolveSpace(int player, int space) {
    if (_propertySpace(space)) {
      final price = _price(space);
      final owner = _owners[space];
      if (owner == null && _money[player] >= price) {
        if (player == 0) {
          setState(() {
            _money[player] -= price;
            _owners[space] = player;
          });
        } else if (_money[player] > price + 100) {
          setState(() {
            _money[player] -= price;
            _owners[space] = player;
          });
        }
      } else if (owner != null && owner != player) {
        final rent = max(25, price ~/ 4);
        setState(() {
          _money[player] -= rent;
          _money[owner] += rent;
        });
      }
    }

    if (space == 30) {
      setState(() => _positions[player] = 10);
      setState(() => _money[player] -= 50);
    }
    if (space == 4) setState(() => _money[player] -= 100);
    if (space == 38) setState(() => _money[player] -= 100);
  }

  void _finish(String result) {
    if (_finished) return;
    _finished = true;
    widget.onFinished(result);
  }

  void _aiTurn() {
    if (widget.mode != 'ai' || _finished) return;
    Future<void>.delayed(const Duration(milliseconds: 650), () async {
      if (!mounted || _finished) return;
      setState(() => _rolling = true);
      for (var i = 0; i < 9; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 65));
        if (!mounted) return;
        setState(() => _dice = [1 + _random.nextInt(6), 1 + _random.nextInt(6)]);
      }
      if (!mounted) return;
      setState(() => _rolling = false);
      await _movePlayer(1);
      if (!_finished) setState(() => _current = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = min<double>(
      widget.theme.boardSize,
      MediaQuery.sizeOf(context).width - 32,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _finished ? 'Game finished' : '${_current == 0 ? 'You' : 'AI'} • Balance: ${_money[_current]}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                AnimatedDiceDisplay(values: _dice, rolling: _rolling, size: 46),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 11,
                ),
                itemCount: 121,
                itemBuilder: (_, index) {
                  final row = index ~/ 11;
                  final col = index % 11;
                  int? space;
                  if (row == 0) {
                    space = col;
                  } else if (col == 10) {
                    space = 10 + row;
                  } else if (row == 10) {
                    space = 30 - col;
                  } else if (col == 0) {
                    space = 40 - row;
                  }

                  if (space == null || space < 0 || space >= 40) {
                    return Container(
                      margin: const EdgeInsets.all(1),
                      color: widget.theme.dark.withValues(alpha: .22),
                      child: (row >= 3 && row <= 7 && col >= 3 && col <= 7)
                          ? const Center(child: Icon(Icons.change_history_rounded, size: 22))
                          : null,
                    );
                  }

                  final player0 = _positions[0] == space;
                  final player1 = _positions[1] == space;
                  return Container(
                    margin: const EdgeInsets.all(1),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .06),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${space + 1}', style: const TextStyle(fontSize: 8)),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (player0) const Icon(Icons.person, size: 17),
                                if (player1) const Icon(Icons.smart_toy, size: 17),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _names[space],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text('You: ${_money[0]} • AI: ${_money[1]}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _current == 0 && !_rolling && !_finished ? _rollAndMove : null,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(_rolling ? 'Rolling…' : 'Roll 2 dice'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_reset),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BackgammonGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const BackgammonGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<BackgammonGameBoard> createState() => _BackgammonGameBoardState();
}

class _BackgammonGameBoardState extends State<BackgammonGameBoard> {
  final Random _random = Random();
  late List<int> _points;
  List<int> _dice = const [1, 1];
  List<int> _movesLeft = const [];
  int _turn = 0;
  int _selected = -1;
  int _barWhite = 0;
  int _barBlack = 0;
  int _borneWhite = 0;
  int _borneBlack = 0;
  bool _rolling = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    // Positive pieces move from point 1 -> 24; negative pieces move 24 -> 1.
    _points = [
      2, 0, 0, 0, 0, -5,
      0, -3, 0, 0, 0, 5,
      -5, 0, 0, 0, 3, 0,
      5, 0, 0, 0, 0, -2,
    ];
    if (widget.variant == 'nackgammon') {
      _points = [
        2, 0, 0, 0, 0, -4,
        0, -4, 0, 0, 0, 5,
        -5, 0, 0, 0, 4, 0,
        4, 0, 0, 0, 0, -2,
      ];
    }
    _dice = const [1, 1];
    _movesLeft = const [];
    _turn = 0;
    _selected = -1;
    _barWhite = 0;
    _barBlack = 0;
    _borneWhite = 0;
    _borneBlack = 0;
    _rolling = false;
    _finished = false;
  }

  int get _currentBar => _turn == 0 ? _barWhite : _barBlack;
  int _dieForMove(int delta) => delta;

  bool _canLand(int target, int side) {
    if (target < 0 || target >= 24) return false;
    final value = _points[target];
    return side == 0 ? value >= -1 : value <= 1;
  }

  bool _allHome(int side) {
    if (side == 0) {
      for (var i = 0; i < 18; i++) {
        if (_points[i] > 0) return false;
      }
    } else {
      for (var i = 6; i < 24; i++) {
        if (_points[i] < 0) return false;
      }
    }
    return true;
  }

  bool _legalMove(int from, int die) {
    final side = _turn;
    final distance = _dieForMove(die);
    if (distance <= 0) return false;

    if (_currentBar > 0) {
      final entry = side == 0 ? distance - 1 : 24 - distance;
      return _canLand(entry, side) && from == -1;
    }

    if (from < 0 || from >= 24) return false;
    if (side == 0 && _points[from] <= 0) return false;
    if (side == 1 && _points[from] >= 0) return false;

    final target = side == 0 ? from + distance : from - distance;
    if (target >= 0 && target < 24) return _canLand(target, side);
    return _allHome(side);
  }

  Future<void> _rollDice() async {
    if (_finished || _rolling || _movesLeft.isNotEmpty) return;
    setState(() => _rolling = true);
    for (var i = 0; i < 9; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 65));
      if (!mounted) return;
      setState(() {
        _dice = [1 + _random.nextInt(6), 1 + _random.nextInt(6)];
      });
    }
    if (!mounted) return;
    final rolled = _dice;
    setState(() {
      _rolling = false;
      _movesLeft = rolled[0] == rolled[1]
          ? [rolled[0], rolled[0], rolled[0], rolled[0]]
          : [rolled[0], rolled[1]];
      _selected = -1;
    });
    if (!_hasAnyLegalMove()) {
      setState(() => _movesLeft = const []);
      setState(() => _turn = 1 - _turn);
      if (_turn == 1 && widget.mode == 'ai') _runAiTurn();
    }
  }

  bool _hasAnyLegalMove() {
    if (_currentBar > 0) {
      return _movesLeft.any((die) => _legalMove(-1, die));
    }
    for (var from = 0; from < 24; from++) {
      if (_movesLeft.any((die) => _legalMove(from, die))) return true;
    }
    return false;
  }

  void _tapPoint(int point) {
    if (_finished || _rolling || _turn != 0 || _movesLeft.isEmpty) return;
    if (_selected == -1) {
      if (_barWhite > 0) return;
      final hasMove = _movesLeft.any((die) => _legalMove(point, die));
      if (hasMove) setState(() => _selected = point);
      return;
    }

    final distance = _turn == 0 ? point - _selected : _selected - point;
    final die = _movesLeft.firstWhere(
      (value) => value == distance,
      orElse: () => 0,
    );
    if (die <= 0) return;
    _makeMove(_selected, die);
  }

  void _makeMove(int from, int die) {
    if (!_legalMove(from, die)) return;
    final side = _turn;
    final target = side == 0 ? from + die : from - die;
    setState(() {
      if (from == -1) {
        if (side == 0) {
          _barWhite--;
        } else {
          _barBlack--;
        }
      } else {
        _points[from] += side == 0 ? -1 : 1;
      }

      if (target >= 0 && target < 24) {
        final occupant = _points[target];
        if (side == 0 && occupant == -1) {
          _barBlack++;
          _points[target] = 1;
        } else if (side == 1 && occupant == 1) {
          _barWhite++;
          _points[target] = -1;
        } else {
          _points[target] += side == 0 ? 1 : -1;
        }
      } else {
        if (side == 0) {
          _borneWhite++;
        } else {
          _borneBlack++;
        }
      }

      final remaining = List<int>.from(_movesLeft)..remove(die);
      _movesLeft = remaining;
      _selected = -1;
    });

    if (_borneWhite >= 15) {
      _finished = true;
      widget.onFinished('win');
      return;
    }
    if (_borneBlack >= 15) {
      _finished = true;
      widget.onFinished('loss');
      return;
    }

    if (_movesLeft.isEmpty || !_hasAnyLegalMove()) {
      setState(() => _turn = 1 - _turn);
      if (_turn == 1 && widget.mode == 'ai') _runAiTurn();
    }
  }

  void _runAiTurn() {
    if (_finished || widget.mode != 'ai' || _turn != 1) return;
    Future<void>.delayed(const Duration(milliseconds: 650), () async {
      if (!mounted || _finished || _turn != 1) return;
      await _rollDice();
      if (!mounted || _finished || _turn != 1) return;
      while (_movesLeft.isNotEmpty && _hasAnyLegalMove()) {
        final usableDice = _movesLeft
            .where((die) => _currentBar > 0
                ? _legalMove(-1, die)
                : List<int>.generate(24, (i) => i).any((i) => _legalMove(i, die)))
            .toList(growable: false);
        if (usableDice.isEmpty) break;
        final die = usableDice.first;

        if (_currentBar > 0) {
          _makeMove(-1, die);
          continue;
        }

        var from = -1;
        for (var i = 0; i < 24; i++) {
          if (_legalMove(i, die)) {
            from = i;
            break;
          }
        }
        if (from == -1) break;
        _makeMove(from, die);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = min<double>(
      widget.theme.boardSize,
      MediaQuery.sizeOf(context).width - 32,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _finished
                        ? 'Game finished'
                        : _turn == 0
                            ? 'White to move'
                            : 'Black to move',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                AnimatedDiceDisplay(values: _dice, rolling: _rolling, size: 46),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: boardSize,
              height: boardSize * .82,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 12,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                ),
                itemCount: 24,
                itemBuilder: (_, index) {
                  final white = _points[index] > 0;
                  final count = _points[index].abs();
                  return GestureDetector(
                    onTap: () => _tapPoint(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? widget.theme.light
                            : widget.theme.dark,
                        border: Border.all(
                          color: _selected == index
                              ? widget.theme.accent
                              : Colors.black.withValues(alpha: .18),
                          width: _selected == index ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${index + 1}', style: const TextStyle(fontSize: 10)),
                            if (count > 0)
                              CircleAvatar(
                                radius: min(18.0, 7.0 + count * 1.5),
                                child: Text('$count'),
                              ),
                            if (count == 0)
                              Icon(
                                white ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 13,
                                color: Colors.black38,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bar: White $_barWhite • Black $_barBlack • Home: White $_borneWhite / 15 • Black $_borneBlack / 15',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _movesLeft.isEmpty
                  ? 'Roll two dice to receive your legal moves. Doubles provide four moves.'
                  : 'Moves remaining: ${_movesLeft.join(', ')}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _turn == 0 && !_rolling && !_finished && _movesLeft.isEmpty
                      ? _rollDice
                      : null,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(_rolling ? 'Rolling…' : 'Roll 2 dice'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_reset),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SorryGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const SorryGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<SorryGameBoard> createState() => _SorryGameBoardState();
}

class _SorryGameBoardState extends State<SorryGameBoard> {
  final Random _random = Random();
  final List<int> _you = [0, 0, 0, 0];
  final List<int> _opponent = [0, 0, 0, 0];
  int _current = 0;
  int _card = 1;
  bool _drawing = false;
  bool _finished = false;

  Future<void> _drawCard() async {
    if (_drawing || _finished || _current != 0) return;
    setState(() => _drawing = true);
    for (var i = 0; i < 7; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() => _card = 1 + _random.nextInt(12));
    }
    if (!mounted) return;
    setState(() => _drawing = false);
    _playCard();
  }

  void _playCard() {
    final piece = _you.indexWhere((value) => value < 44);
    if (piece == -1) {
      _finish('win');
      return;
    }
    setState(() {
      _you[piece] = min(44, _you[piece] + (_card == 4 ? 4 : _card));
      final landing = _you[piece];
      for (var i = 0; i < _opponent.length; i++) {
        if (_opponent[i] == landing && landing > 0 && landing < 44) {
          _opponent[i] = 0;
        }
      }
    });
    if (_you.every((p) => p >= 44)) {
      _finish('win');
      return;
    }
    setState(() => _current = 1);
    _aiTurn();
  }

  void _aiTurn() {
    if (widget.mode != 'ai' || _finished) return;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || _finished) return;
      final card = 1 + _random.nextInt(12);
      final piece = _opponent.indexWhere((value) => value < 44);
      if (piece >= 0) {
        setState(() => _opponent[piece] = min(44, _opponent[piece] + card));
      }
      if (_opponent.every((p) => p >= 44)) {
        _finish('loss');
      } else {
        setState(() => _current = 0);
      }
    });
  }

  void _finish(String result) {
    if (_finished) return;
    _finished = true;
    widget.onFinished(result);
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = min<double>(
      widget.theme.boardSize,
      MediaQuery.sizeOf(context).width - 32,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _current == 0 ? 'Your turn' : 'AI / Player 2 turn',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                  child: Container(
                    key: ValueKey(_card),
                    width: 50,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_card', style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: boardSize,
              height: boardSize * .56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.theme.dark.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: .14)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('SORRY! track • card-driven movement', style: TextStyle(fontWeight: FontWeight.w800)),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SorryRow(label: 'You', pieces: _you, icon: Icons.person),
                          _SorryRow(label: 'AI', pieces: _opponent, icon: Icons.smart_toy),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Classic Sorry! is card-driven, not dice-driven. Draw a card, move a pawn, and bump an opponent back to start.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _current == 0 && !_drawing && !_finished ? _drawCard : null,
              icon: const Icon(Icons.style_rounded),
              label: Text(_drawing ? 'Drawing…' : 'Draw card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SorryRow extends StatelessWidget {
  final String label;
  final List<int> pieces;
  final IconData icon;

  const _SorryRow({required this.label, required this.pieces, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final piece in pieces)
              Chip(label: Text(piece >= 44 ? 'HOME' : '$piece')),
          ],
        ),
      ],
    );
  }
}

class ChessGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const ChessGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<ChessGameBoard> createState() => _ChessGameBoardState();
}

class _ChessGameBoardState extends State<ChessGameBoard> {
  final Random _random = Random();
  late List<String?> _board;
  int _turn = 0;
  int? _selected;
  bool _thinking = false;
  bool _finished = false;
  bool _whiteKingMoved = false;
  bool _blackKingMoved = false;
  bool _whiteRookAMoved = false;
  bool _whiteRookHMoved = false;
  bool _blackRookAMoved = false;
  bool _blackRookHMoved = false;
  int? _enPassantTarget;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    _board = List<String?>.filled(64, null);
    const backRank = ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'];
    for (var col = 0; col < 8; col++) {
      _board[col] = backRank[col];
      _board[8 + col] = 'p';
      _board[48 + col] = 'P';
      _board[56 + col] = backRank[col].toUpperCase();
    }
    _turn = 0;
    _selected = null;
    _thinking = false;
    _finished = false;
    _whiteKingMoved = false;
    _blackKingMoved = false;
    _whiteRookAMoved = false;
    _whiteRookHMoved = false;
    _blackRookAMoved = false;
    _blackRookHMoved = false;
    _enPassantTarget = null;
  }

  bool _isWhite(String piece) => piece == piece.toUpperCase();
  int _sideOf(String piece) => _isWhite(piece) ? 0 : 1;
  int _row(int index) => index ~/ 8;
  int _col(int index) => index % 8;

  bool _inside(int row, int col) =>
      row >= 0 && row < 8 && col >= 0 && col < 8;

  List<int> _pseudoMoves(
    List<String?> board,
    int index,
    int side, {
    bool includeCastling = false,
  }) {
    final piece = board[index];
    if (piece == null || _sideOf(piece) != side) return const <int>[];

    final row = _row(index);
    final col = _col(index);
    final kind = piece.toLowerCase();
    final result = <int>[];

    void add(int r, int c) {
      if (!_inside(r, c)) return;
      final target = r * 8 + c;
      final occupant = board[target];
      if (occupant == null || _sideOf(occupant) != side) {
        if (occupant?.toLowerCase() != 'k') {
          result.add(target);
        }
      }
    }

    bool addRay(int r, int c, int dr, int dc) {
      while (_inside(r, c)) {
        final target = r * 8 + c;
        final occupant = board[target];
        if (occupant == null) {
          result.add(target);
        } else {
          if (_sideOf(occupant) != side && occupant.toLowerCase() != 'k') {
            result.add(target);
          }
          return false;
        }
        r += dr;
        c += dc;
      }
      return false;
    }

    if (kind == 'p') {
      final direction = side == 0 ? -1 : 1;
      final startRow = side == 0 ? 6 : 1;
      final oneRow = row + direction;
      if (_inside(oneRow, col)) {
        final one = oneRow * 8 + col;
        if (board[one] == null) {
          result.add(one);
          if (row == startRow) {
            final twoRow = row + direction * 2;
            final two = twoRow * 8 + col;
            if (board[two] == null) result.add(two);
          }
        }
        for (final dc in const [-1, 1]) {
          final captureCol = col + dc;
          if (!_inside(oneRow, captureCol)) continue;
          final target = oneRow * 8 + captureCol;
          final occupant = board[target];
          if (occupant != null &&
              _sideOf(occupant) != side &&
              occupant.toLowerCase() != 'k') {
            result.add(target);
          }
          if (_enPassantTarget == target && board[target] == null) {
            result.add(target);
          }
        }
      }
    } else if (kind == 'n') {
      for (final d in const [
        [-2, -1],
        [-2, 1],
        [-1, -2],
        [-1, 2],
        [1, -2],
        [1, 2],
        [2, -1],
        [2, 1],
      ]) {
        add(row + d[0], col + d[1]);
      }
    } else if (kind == 'b') {
      for (final d in const [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]) {
        addRay(row + d[0], col + d[1], d[0], d[1]);
      }
    } else if (kind == 'r') {
      for (final d in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        addRay(row + d[0], col + d[1], d[0], d[1]);
      }
    } else if (kind == 'q') {
      for (final d in const [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        addRay(row + d[0], col + d[1], d[0], d[1]);
      }
    } else if (kind == 'k') {
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          add(row + dr, col + dc);
        }
      }

      if (includeCastling && !_isInCheck(board, side)) {
        if (side == 0 && !_whiteKingMoved && row == 7 && col == 4) {
          if (!_whiteRookHMoved &&
              board[63] == 'R' &&
              board[61] == null &&
              board[62] == null &&
              !_squareAttacked(board, 61, 1) &&
              !_squareAttacked(board, 62, 1)) {
            result.add(62);
          }
          if (!_whiteRookAMoved &&
              board[56] == 'R' &&
              board[57] == null &&
              board[58] == null &&
              board[59] == null &&
              !_squareAttacked(board, 59, 1) &&
              !_squareAttacked(board, 58, 1)) {
            result.add(58);
          }
        } else if (side == 1 && !_blackKingMoved && row == 0 && col == 4) {
          if (!_blackRookHMoved &&
              board[7] == 'r' &&
              board[5] == null &&
              board[6] == null &&
              !_squareAttacked(board, 5, 0) &&
              !_squareAttacked(board, 6, 0)) {
            result.add(6);
          }
          if (!_blackRookAMoved &&
              board[0] == 'r' &&
              board[1] == null &&
              board[2] == null &&
              board[3] == null &&
              !_squareAttacked(board, 3, 0) &&
              !_squareAttacked(board, 2, 0)) {
            result.add(2);
          }
        }
      }
    }

    return result;
  }

  bool _squareAttacked(List<String?> board, int square, int bySide) {
    final row = _row(square);
    final col = _col(square);

    final pawnRow = row + (bySide == 0 ? 1 : -1);
    for (final dc in const [-1, 1]) {
      final pawnCol = col + dc;
      if (!_inside(pawnRow, pawnCol)) continue;
      if (board[pawnRow * 8 + pawnCol] == (bySide == 0 ? 'P' : 'p')) {
        return true;
      }
    }

    for (final d in const [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ]) {
      final r = row + d[0];
      final c = col + d[1];
      if (_inside(r, c) && board[r * 8 + c] == (bySide == 0 ? 'N' : 'n')) {
        return true;
      }
    }

    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (_inside(r, c) && board[r * 8 + c] == (bySide == 0 ? 'K' : 'k')) {
          return true;
        }
      }
    }

    for (final d in const [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      var r = row + d[0];
      var c = col + d[1];
      while (_inside(r, c)) {
        final piece = board[r * 8 + c];
        if (piece != null) {
          if (_sideOf(piece) == bySide &&
              (piece.toLowerCase() == 'r' || piece.toLowerCase() == 'q')) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }

    for (final d in const [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ]) {
      var r = row + d[0];
      var c = col + d[1];
      while (_inside(r, c)) {
        final piece = board[r * 8 + c];
        if (piece != null) {
          if (_sideOf(piece) == bySide &&
              (piece.toLowerCase() == 'b' || piece.toLowerCase() == 'q')) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }

    return false;
  }

  int? _kingSquare(List<String?> board, int side) {
    final king = side == 0 ? 'K' : 'k';
    for (var i = 0; i < board.length; i++) {
      if (board[i] == king) return i;
    }
    return null;
  }

  bool _isInCheck(List<String?> board, int side) {
    final king = _kingSquare(board, side);
    return king != null && _squareAttacked(board, king, 1 - side);
  }

  List<int> _legalMovesFor(int index) {
    final piece = _board[index];
    if (piece == null || _sideOf(piece) != _turn) {
      return const <int>[];
    }

    final result = <int>[];
    for (final target in _pseudoMoves(
      _board,
      index,
      _turn,
      includeCastling: true,
    )) {
      final copy = List<String?>.from(_board);
      _applyMoveOnBoard(copy, index, target);
      if (!_isInCheck(copy, _turn)) result.add(target);
    }
    return result;
  }

  List<List<int>> _allLegalMoves(int side) {
    final moves = <List<int>>[];
    for (var i = 0; i < 64; i++) {
      final piece = _board[i];
      if (piece == null || _sideOf(piece) != side) continue;
      for (final target in _pseudoMoves(
        _board,
        i,
        side,
        includeCastling: side == _turn,
      )) {
        final copy = List<String?>.from(_board);
        _applyMoveOnBoard(copy, i, target);
        if (!_isInCheck(copy, side)) moves.add([i, target]);
      }
    }
    return moves;
  }

  void _applyMoveOnBoard(List<String?> board, int from, int to) {
    final piece = board[from];
    if (piece == null) return;
    final targetRow = _row(to);

    if (piece.toLowerCase() == 'p' &&
        board[to] == null &&
        to == _enPassantTarget) {
      final capture = to + (_isWhite(piece) ? 8 : -8);
      if (capture >= 0 && capture < 64) board[capture] = null;
    }

    if (piece.toLowerCase() == 'k' && (to - from).abs() == 2) {
      if (to > from) {
        board[to - 1] = board[from + 3];
        board[from + 3] = null;
      } else {
        board[to + 1] = board[from - 4];
        board[from - 4] = null;
      }
    }

    board[to] = piece;
    board[from] = null;
    if (piece.toLowerCase() == 'p' && targetRow == 0) board[to] = 'Q';
    if (piece.toLowerCase() == 'p' && targetRow == 7) board[to] = 'q';
  }

  void _updateCastleRights(String moving, int from, String? captured, int to) {
    if (moving == 'K') _whiteKingMoved = true;
    if (moving == 'k') _blackKingMoved = true;
    if (moving == 'R') {
      if (from == 56) _whiteRookAMoved = true;
      if (from == 63) _whiteRookHMoved = true;
    }
    if (moving == 'r') {
      if (from == 0) _blackRookAMoved = true;
      if (from == 7) _blackRookHMoved = true;
    }
    if (captured == 'R') {
      if (to == 56) _whiteRookAMoved = true;
      if (to == 63) _whiteRookHMoved = true;
    }
    if (captured == 'r') {
      if (to == 0) _blackRookAMoved = true;
      if (to == 7) _blackRookHMoved = true;
    }
  }

  void _move(int from, int to) {
    final moving = _board[from];
    if (moving == null) return;
    final captured = _board[to];
    final isPawn = moving.toLowerCase() == 'p';
    final previousEnPassant = _enPassantTarget;

    // En-passant capture.
    if (isPawn && _board[to] == null && to == previousEnPassant) {
      final capturedSquare = to + (_isWhite(moving) ? 8 : -8);
      if (capturedSquare >= 0 && capturedSquare < 64) {
        _board[capturedSquare] = null;
      }
    }

    if (moving.toLowerCase() == 'k' && (to - from).abs() == 2) {
      if (to > from) {
        final rookFrom = from + 3;
        _board[to - 1] = _board[rookFrom];
        _board[rookFrom] = null;
      } else {
        final rookFrom = from - 4;
        _board[to + 1] = _board[rookFrom];
        _board[rookFrom] = null;
      }
    }

    _board[to] = moving;
    _board[from] = null;

    if (moving == 'P') {
      if (_row(to) == 0) _board[to] = 'Q';
      _enPassantTarget = from - 16 == to ? from - 8 : null;
    } else if (moving == 'p') {
      if (_row(to) == 7) _board[to] = 'q';
      _enPassantTarget = from + 16 == to ? from + 8 : null;
    } else {
      _enPassantTarget = null;
    }

    _updateCastleRights(moving, from, captured, to);

    setState(() {
      _selected = null;
      _turn = 1 - _turn;
    });

    final nextMoves = _allLegalMoves(_turn);
    final inCheck = _isInCheck(_board, _turn);
    if (nextMoves.isEmpty) {
      _finished = true;
      if (inCheck) {
        widget.onFinished(_turn == 0 ? 'loss' : 'win');
      } else {
        widget.onFinished('draw');
      }
      return;
    }

    if (widget.mode == 'ai' && _turn == 1) {
      _runAiTurn(nextMoves);
    }
  }

  int _pieceValue(String? piece) => switch (piece?.toLowerCase()) {
        'p' => 100,
        'n' => 320,
        'b' => 330,
        'r' => 500,
        'q' => 900,
        'k' => 20000,
        _ => 0,
      };

  List<int> _chooseAiMove(List<List<int>> moves) {
    final difficulty = widget.difficulty == 'random'
        ? _random.nextInt(7)
        : _GamePlayCatalog.difficulties.indexOf(widget.difficulty).clamp(0, 6);
    if (difficulty <= 1) return moves[_random.nextInt(moves.length)];

    var bestScore = -1 << 30;
    var bestMoves = <List<int>>[];

    for (final move in moves) {
      final copy = List<String?>.from(_board);
      final targetPiece = copy[move[1]];
      _applyMoveOnBoard(copy, move[0], move[1]);
      var score = _pieceValue(targetPiece);
      if (_isInCheck(copy, 0)) score += 120;
      if (targetPiece?.toLowerCase() == 'q') score += 40;
      if (targetPiece?.toLowerCase() == 'r') score += 20;
      if (difficulty >= 5) {
        // Prefer moves that also preserve the black king and material.
        for (var i = 0; i < copy.length; i++) {
          final p = copy[i];
          if (p != null) {
            score += _sideOf(p) == 1 ? _pieceValue(p) : -(_pieceValue(p) ~/ 10);
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMoves = [move];
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }

    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  void _runAiTurn(List<List<int>> legalMoves) {
    if (!mounted || _finished || _thinking) return;
    setState(() => _thinking = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _finished) return;
      final choice = _chooseAiMove(legalMoves);
      _thinking = false;
      _move(choice[0], choice[1]);
    });
  }

  void _tapSquare(int index) {
    if (_thinking || _finished || _turn != 0) return;
    final piece = _board[index];

    if (_selected == null) {
      if (piece == null || !_isWhite(piece)) return;
      if (_legalMovesFor(index).isEmpty) return;
      setState(() => _selected = index);
      return;
    }

    final legal = _legalMovesFor(_selected!);
    if (legal.contains(index)) {
      _move(_selected!, index);
      return;
    }

    if (piece != null && _isWhite(piece)) {
      setState(() {
        _selected = _legalMovesFor(index).isEmpty ? null : index;
      });
    } else {
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final boardSize = min<double>(
      widget.theme.boardSize,
      min<double>(maxWidth, 680.0),
    );
    final inCheck = _isInCheck(_board, _turn);
    final legalMoves = _selected == null
        ? const <int>[]
        : _legalMovesFor(_selected!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _finished
                        ? 'Game finished'
                        : _thinking
                            ? 'AI is thinking…'
                            : inCheck
                                ? (_turn == 0 ? 'White is in check' : 'Black is in check')
                                : (_turn == 0 ? 'White to move' : 'Black to move'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(widget.variant)),
                IconButton(
                  tooltip: 'Restart',
                  onPressed: _resetBoard,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemCount: 64,
                itemBuilder: (context, index) {
                  final row = _row(index);
                  final col = _col(index);
                  final isLight = (row + col).isEven;
                  final selected = _selected == index;
                  final legal = legalMoves.contains(index);
                  final piece = _board[index];

                  return GestureDetector(
                    onTap: () => _tapSquare(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? widget.theme.accent.withValues(alpha: .72)
                            : legal
                                ? widget.theme.accent.withValues(alpha: .32)
                                : isLight
                                    ? widget.theme.light
                                    : widget.theme.dark,
                      ),
                      child: Center(
                        child: piece == null
                            ? legal
                                ? Container(
                                    width: boardSize / 38,
                                    height: boardSize / 38,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: .38),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const SizedBox.shrink()
                            : Text(
                                _chessGlyph(piece),
                                style: TextStyle(
                                  fontSize: boardSize / 12.5,
                                  color: _isWhite(piece)
                                      ? Colors.white
                                      : Colors.black,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: .42),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              inCheck
                  ? 'CHECK — the king is under attack. Only legal moves that remove check are allowed.'
                  : 'Full check/checkmate legality, castling, en passant and pawn promotion are enabled.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  String _chessGlyph(String piece) => switch (piece) {
        'K' => '♔',
        'Q' => '♕',
        'R' => '♖',
        'B' => '♗',
        'N' => '♘',
        'P' => '♙',
        'k' => '♚',
        'q' => '♛',
        'r' => '♜',
        'b' => '♝',
        'n' => '♞',
        'p' => '♟',
        _ => '',
      };
}

class PracticeGameBoard extends StatefulWidget {
  final GameDefinition game;
  final BoardThemeConfig theme;
  final String mode;
  final Future<void> Function(String result) onFinished;
  final String difficulty;
  final String variant;

  const PracticeGameBoard({
    super.key,
    required this.game,
    required this.theme,
    required this.mode,
    required this.onFinished,
    this.difficulty = 'medium',
    this.variant = 'standard',
  });

  @override
  State<PracticeGameBoard> createState() => _PracticeGameBoardState();
}

class _SudokuCage {
  final List<int> cells;
  final int target;

  const _SudokuCage(this.cells, this.target);
}

class _SudokuRelation {
  final int a;
  final int b;
  final String symbol;

  const _SudokuRelation(this.a, this.b, this.symbol);
}

class _SudokuArrow {
  final int circle;
  final List<int> path;
  final int target;

  const _SudokuArrow(this.circle, this.path, this.target);
}

class _PracticeGameBoardState extends State<PracticeGameBoard> {
  final Random _random = Random();
  late String _difficulty;
  late String _variant;
  late List<int> _puzzle;
  late List<int> _solution;
  late List<bool> _given;
  late List<int> _regions;

  List<_SudokuCage> _cages = const <_SudokuCage>[];
  List<_SudokuRelation> _greaterThan = const <_SudokuRelation>[];
  List<_SudokuArrow> _arrows = const <_SudokuArrow>[];
  List<List<int>> _thermos = const <List<int>>[];
  Set<String> _consecutiveEdges = <String>{};
  Set<int> _evenCells = <int>{};
  Set<int> _oddCells = <int>{};

  int _moves = 0;
  bool _finished = false;

  bool get _isSudoku => widget.game.id == 'sudoku' || widget.game.id == 'jigsaw';

  int get _size => switch (_variant) {
        'mini_4x4' => 4,
        'mega_25x25' => 25,
        _ => 9,
      };

  int get _boxSize => _size == 4 ? 2 : _size == 9 ? 3 : 5;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty;
    _variant = widget.variant;
    if (widget.game.id == 'jigsaw' && _variant == 'standard') {
      _variant = 'irregular_9x9';
    }
    _reset();
  }

  void _reset() {
    _moves = 0;
    _finished = false;
    if (_isSudoku) {
      _generateSudoku();
    } else {
      _puzzle = const <int>[];
      _given = const <bool>[];
      _solution = const <int>[];
      _regions = const <int>[];
    }
  }

  void _generateSudoku() {
    final n = _size;
    _regions = _buildRegions();
    _solution = List<int>.filled(n * n, 0);

    _solution = switch (_variant) {
      'windoku_9x9' => _windokuSolution(),
      'x_9x9' => _xSudokuSolution(),
      _ => _baseSolution(n),
    };

    _buildVariantConstraints();
    _puzzle = List<int>.from(_solution);
    _given = List<bool>.filled(n * n, true);

    final difficulty = _difficulty == 'random'
        ? _GamePlayCatalog.difficulties[_random.nextInt(6)]
        : _difficulty;
    final removal = switch (difficulty) {
      'easy' => .30,
      'medium' => .43,
      'hard' => .52,
      'expert' => .60,
      'master' => .67,
      'grandmaster' => .73,
      _ => .43,
    };

    final indexes = List<int>.generate(n * n, (i) => i)..shuffle(_random);
    final removeCount = (n * n * removal).round();
    for (final index in indexes.take(removeCount)) {
      _puzzle[index] = 0;
      _given[index] = false;
    }
  }

  List<int> _baseSolution(int n) {
    return List<int>.generate(n * n, (index) {
      final r = index ~/ n;
      final c = index % n;
      return ((r * _boxSize + r ~/ _boxSize + c) % n) + 1;
    });
  }

  List<int> _windokuSolution() => const [
    4, 9, 6, 7, 3, 1, 8, 2, 5,
    3, 2, 5, 9, 6, 8, 7, 1, 4,
    8, 7, 1, 4, 2, 5, 3, 6, 9,
    5, 8, 3, 6, 1, 2, 4, 9, 7,
    7, 1, 4, 8, 9, 3, 6, 5, 2,
    2, 6, 9, 5, 7, 4, 1, 3, 8,
    9, 3, 8, 2, 4, 6, 5, 7, 1,
    6, 4, 7, 1, 5, 9, 2, 8, 3,
    1, 5, 2, 3, 8, 7, 9, 4, 6,
  ];

  List<int> _xSudokuSolution() => const [
    9, 6, 1, 8, 4, 3, 2, 5, 7,
    5, 8, 4, 7, 2, 6, 1, 9, 3,
    3, 2, 7, 1, 9, 5, 6, 4, 8,
    1, 5, 8, 6, 7, 4, 9, 3, 2,
    4, 7, 6, 9, 3, 2, 8, 1, 5,
    2, 3, 9, 5, 8, 1, 4, 7, 6,
    7, 4, 2, 3, 6, 9, 5, 8, 1,
    6, 1, 3, 4, 5, 8, 7, 2, 9,
    8, 9, 5, 2, 1, 7, 3, 6, 4,
  ];

  List<int> _buildRegions() {
    if (_size != 9 || (_variant != 'jigsaw_9x9' && _variant != 'irregular_9x9')) {
      return List<int>.generate(_size * _size, (index) {
        final r = index ~/ _size;
        final c = index % _size;
        return (r ~/ _boxSize) * _boxSize + c ~/ _boxSize;
      });
    }

    // Nine connected polyominoes. The partition is deliberately irregular,
    // but every region contains exactly nine cells.
    const map = <String>[
      'IIIHHHGGG',
      'IIIHHHGGG',
      'IIIHHHGGG',
      'BBBAAACCC',
      'BBBAAAACC',
      'BBBDAACCC',
      'FFFDDDEEC',
      'FFFDDEEEE',
      'FFFDDDEEE',
    ];
    return List<int>.generate(81, (index) => map[index ~/ 9].codeUnitAt(index % 9) - 65);
  }

  void _buildVariantConstraints() {
    _cages = const <_SudokuCage>[];
    _greaterThan = const <_SudokuRelation>[];
    _arrows = const <_SudokuArrow>[];
    _thermos = const <List<int>>[];
    _consecutiveEdges = <String>{};
    _evenCells = <int>{};
    _oddCells = <int>{};

    if (_size != 9) return;

    if (_variant == 'killer_9x9') {
      final used = <int>{};
      final cages = <_SudokuCage>[];
      final order = List<int>.generate(81, (i) => i)..shuffle(_random);
      for (final start in order) {
        if (used.contains(start)) continue;
        final cells = <int>[start];
        used.add(start);
        final desired = 1 + _random.nextInt(3);
        while (cells.length < desired) {
          final candidates = <int>[];
          for (final cell in cells) {
            final r = cell ~/ 9;
            final c = cell % 9;
            for (final n in [cell - 9, cell + 9, cell - 1, cell + 1]) {
              if (n < 0 || n >= 81 || used.contains(n)) continue;
              final nr = n ~/ 9;
              final nc = n % 9;
              if ((nr - r).abs() + (nc - c).abs() == 1 &&
                  !cells.any((x) => _solution[x] == _solution[n])) {
                candidates.add(n);
              }
            }
          }
          if (candidates.isEmpty) break;
          final next = candidates[_random.nextInt(candidates.length)];
          cells.add(next);
          used.add(next);
        }
        final target = cells.fold<int>(0, (sum, cell) => sum + _solution[cell]);
        cages.add(_SudokuCage(List<int>.from(cells), target));
      }
      _cages = cages;
    }

    if (_variant == 'greater_than_9x9') {
      final relations = <_SudokuRelation>[];
      final candidates = <_SudokuRelation>[];
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final index = r * 9 + c;
          if (c < 8) {
            final b = index + 1;
            candidates.add(_SudokuRelation(index, b, _solution[index] > _solution[b] ? '>' : '<'));
          }
          if (r < 8) {
            final b = index + 9;
            candidates.add(_SudokuRelation(index, b, _solution[index] > _solution[b] ? '>' : '<'));
          }
        }
      }
      candidates.shuffle(_random);
      relations.addAll(candidates.take(22));
      _greaterThan = relations;
    }

    if (_variant == 'consecutive_9x9') {
      final candidates = <String>[];
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final index = r * 9 + c;
          if (c < 8 && (_solution[index] - _solution[index + 1]).abs() == 1) {
            candidates.add(_edgeKey(index, index + 1));
          }
          if (r < 8 && (_solution[index] - _solution[index + 9]).abs() == 1) {
            candidates.add(_edgeKey(index, index + 9));
          }
        }
      }
      candidates.shuffle(_random);
      _consecutiveEdges = candidates.take(18).toSet();
    }

    if (_variant == 'even_odd_9x9') {
      for (var i = 0; i < 81; i++) {
        if (i % 3 == 0 || i % 7 == 0) {
          (_solution[i].isEven ? _evenCells : _oddCells).add(i);
        }
      }
    }

    if (_variant == 'arrow_thermo_9x9') {
      _thermos = [
        const [0, 1, 2, 3],
        const [40, 31, 22, 13],
      ].where((path) => _isStrictlyIncreasing(path)).toList(growable: false);

      final arrows = <_SudokuArrow>[];
      final candidates = <List<int>>[
        [4, 5, 6, 7],
        [20, 29, 38, 47],
        [60, 61, 62, 63],
        [8, 17, 26, 35],
      ];
      for (final path in candidates) {
        final circle = path.first;
        final arrowPath = path.skip(1).toList(growable: false);
        final target = arrowPath.fold<int>(0, (sum, cell) => sum + _solution[cell]);
        arrows.add(_SudokuArrow(circle, arrowPath, target));
      }
      _arrows = arrows.take(2).toList(growable: false);
    }
  }

  bool _isStrictlyIncreasing(List<int> path) {
    for (var i = 1; i < path.length; i++) {
      if (_solution[path[i - 1]] >= _solution[path[i]]) return false;
    }
    return true;
  }

  String _edgeKey(int a, int b) => a < b ? '$a:$b' : '$b:$a';

  int _cageFor(int index) {
    for (var i = 0; i < _cages.length; i++) {
      if (_cages[i].cells.contains(index)) return i;
    }
    return -1;
  }

  bool _sameRegion(int a, int b) => _regions[a] == _regions[b];

  bool _validPlacement(int index, int value) {
    final row = index ~/ _size;
    final col = index % _size;
    for (var c = 0; c < _size; c++) {
      final other = row * _size + c;
      if (other != index && _puzzle[other] == value) return false;
    }
    for (var r = 0; r < _size; r++) {
      final other = r * _size + col;
      if (other != index && _puzzle[other] == value) return false;
    }
    for (var other = 0; other < _puzzle.length; other++) {
      if (other != index && _sameRegion(index, other) && _puzzle[other] == value) return false;
    }

    if (_variant == 'x_9x9' && _size == 9) {
      if (row == col) {
        for (var i = 0; i < 9; i++) {
          final d = i * 9 + i;
          if (d != index && _puzzle[d] == value) return false;
        }
      }
      if (row + col == 8) {
        for (var i = 0; i < 9; i++) {
          final d = i * 9 + 8 - i;
          if (d != index && _puzzle[d] == value) return false;
        }
      }
    }

    if (_variant == 'windoku_9x9') {
      const starts = [10, 14, 46, 50];
      for (final start in starts) {
        final sr = start ~/ 9;
        final sc = start % 9;
        final inside = row >= sr && row < sr + 3 && col >= sc && col < sc + 3;
        if (!inside) continue;
        for (var r = sr; r < sr + 3; r++) {
          for (var c = sc; c < sc + 3; c++) {
            final other = r * 9 + c;
            if (other != index && _puzzle[other] == value) return false;
          }
        }
      }
    }

    if (_variant == 'consecutive_9x9') {
      for (final edge in _consecutiveEdges) {
        final parts = edge.split(':');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        if (a != index && b != index) continue;
        final other = a == index ? b : a;
        if (_puzzle[other] != 0 && (_puzzle[other] - value).abs() != 1) return false;
      }
    }

    if (_variant == 'nonconsecutive_9x9') {
      for (final delta in const [-1, 1, -9, 9]) {
        final neighbor = index + delta;
        if (neighbor < 0 || neighbor >= _puzzle.length) continue;
        final nr = neighbor ~/ _size;
        final nc = neighbor % _size;
        if ((nr - row).abs() + (nc - col).abs() != 1) continue;
        final existing = _puzzle[neighbor];
        if (existing != 0 && (existing - value).abs() == 1) return false;
      }
    }

    if (_variant == 'even_odd_9x9') {
      if (_evenCells.contains(index) && value.isOdd) return false;
      if (_oddCells.contains(index) && value.isEven) return false;
    }

    if (_variant == 'greater_than_9x9') {
      for (final relation in _greaterThan) {
        if (relation.a != index && relation.b != index) continue;
        final other = relation.a == index ? relation.b : relation.a;
        final otherValue = _puzzle[other];
        if (otherValue == 0) continue;
        final ok = relation.a == index
            ? relation.symbol == '>'
                ? value > otherValue
                : value < otherValue
            : relation.symbol == '>'
                ? otherValue > value
                : otherValue < value;
        if (!ok) return false;
      }
    }

    if (_variant == 'killer_9x9') {
      final cageIndex = _cageFor(index);
      if (cageIndex >= 0) {
        final cage = _cages[cageIndex];
        var sum = value;
        var filled = 1;
        for (final cell in cage.cells) {
          if (cell == index) continue;
          final existing = _puzzle[cell];
          if (existing == 0) continue;
          if (existing == value) return false;
          sum += existing;
          filled++;
        }
        if (sum > cage.target) return false;
        if (filled == cage.cells.length && sum != cage.target) return false;
      }
    }

    if (_variant == 'arrow_thermo_9x9') {
      for (final thermo in _thermos) {
        if (!thermo.contains(index)) continue;
        final position = thermo.indexOf(index);
        if (position > 0) {
          final previous = _puzzle[thermo[position - 1]];
          if (previous != 0 && value <= previous) return false;
        }
        if (position < thermo.length - 1) {
          final next = _puzzle[thermo[position + 1]];
          if (next != 0 && value >= next) return false;
        }
      }
      for (final arrow in _arrows) {
        if (!arrow.path.contains(index)) continue;
        var sum = 0;
        var complete = true;
        for (final cell in arrow.path) {
          final current = cell == index ? value : _puzzle[cell];
          if (current == 0) complete = false;
          sum += current;
        }
        if (sum > arrow.target || (complete && sum != arrow.target)) return false;
      }
    }

    return true;
  }

  void _selectValue(int index, int value) {
    if (_finished || _given[index] || value < 0 || value > _size) return;
    if (value == 0) {
      setState(() {
        _puzzle[index] = 0;
        _moves++;
      });
      return;
    }
    if (!_validPlacement(index, value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That value breaks this variant’s rules.')),
      );
      return;
    }
    setState(() {
      _puzzle[index] = value;
      _moves++;
    });
    if (_puzzle.every((item) => item != 0)) {
      final correct = List.generate(
        _puzzle.length,
        (i) => _puzzle[i] == _solution[i],
      ).every((ok) => ok);
      if (correct) {
        _finished = true;
        widget.onFinished('win');
      }
    }
  }

  String _symbol(int value) {
    if (_size == 25) {
      if (value <= 10) return (value - 1).toString();
      return String.fromCharCode('A'.codeUnitAt(0) + value - 11);
    }
    if (_variant == 'wordoku_9x9') {
      const letters = 'STREAMING';
      return letters[value - 1];
    }
    return value.toString();
  }

  Color _colorForValue(int value) {
    const colors = <Color>[
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.yellowAccent,
      Colors.greenAccent,
      Colors.cyanAccent,
      Colors.lightBlueAccent,
      Colors.indigoAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];
    return colors[(value - 1) % colors.length];
  }

  String get _variantLabel => GameCatalog.instance
      .variant(widget.game.id, _variant)
      .name;

  String get _variantDescription => GameCatalog.instance
      .variant(widget.game.id, _variant)
      .description;

  Future<void> _showValuePicker(BuildContext context, int index) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= _size; n++)
                SizedBox(
                  width: _size > 16 ? 56 : 76,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, n),
                    child: Text(_symbol(n)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 0),
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || value == null) return;
    _selectValue(index, value);
  }

  Widget _cellDecoration(int index, int row, int col, bool given) {
    final regionColor = widget.theme.accent.withValues(
      alpha: _variant == 'color_9x9' && _puzzle[index] != 0 ? .18 : 0,
    );
    final boxBoundary = row % _boxSize == 0 || col % _boxSize == 0 ||
        row == _size - 1 || col == _size - 1;
    final irregularBoundary = _variant == 'jigsaw_9x9' || _variant == 'irregular_9x9';
    return Container(
      decoration: BoxDecoration(
        color: regionColor != Colors.transparent
            ? regionColor
            : given
                ? Colors.white.withValues(alpha: .10)
                : Colors.transparent,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: .24),
            width: irregularBoundary && row > 0 && _regions[index] != _regions[index - 9]
                ? 2.4
                : boxBoundary
                    ? 1.7
                    : .55,
          ),
          left: BorderSide(
            color: Colors.white.withValues(alpha: .24),
            width: irregularBoundary && col > 0 && _regions[index] != _regions[index - 1]
                ? 2.4
                : boxBoundary
                    ? 1.7
                    : .55,
          ),
          right: BorderSide(
            color: Colors.white.withValues(alpha: .24),
            width: col == _size - 1 || (irregularBoundary && col < _size - 1 && _regions[index] != _regions[index + 1])
                ? 2.4
                : .55,
          ),
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: .24),
            width: row == _size - 1 || (irregularBoundary && row < _size - 1 && _regions[index] != _regions[index + _size])
                ? 2.4
                : .55,
          ),
        ),
      ),
    );
  }

  Widget _variantOverlay(int index, double cellSize) {
    final widgets = <Widget>[];

    if (_variant == 'windoku_9x9') {
      final row = index ~/ 9;
      final col = index % 9;
      final hyper = (row >= 1 && row <= 3 && col >= 1 && col <= 3) ||
          (row >= 1 && row <= 3 && col >= 5 && col <= 7) ||
          (row >= 5 && row <= 7 && col >= 1 && col <= 3) ||
          (row >= 5 && row <= 7 && col >= 5 && col <= 7);
      if (hyper) {
        widgets.add(
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: .06),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_variant == 'even_odd_9x9' && _evenCells.contains(index)) {
      widgets.add(
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: .10),
              ),
            ),
          ),
        ),
      );
    }
    if (_variant == 'even_odd_9x9' && _oddCells.contains(index)) {
      widgets.add(
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: .10),
              ),
            ),
          ),
        ),
      );
    }

    final cageIndex = _cageFor(index);
    if (_variant == 'killer_9x9' && cageIndex >= 0) {
      widgets.add(
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .025),
              ),
            ),
          ),
        ),
      );
      if (_cages[cageIndex].cells.first == index) {
        widgets.add(
          Positioned(
            left: 3,
            top: 1,
            child: Text(
              '${_cages[cageIndex].target}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        );
      }
    }

    if (_variant == 'greater_than_9x9') {
      for (final relation in _greaterThan) {
        if (relation.a == index) {
          widgets.add(
            Positioned(
              right: -5,
              top: cellSize / 2 - 9,
              child: Text(
                relation.symbol,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          );
        }
      }
    }

    if (_variant == 'consecutive_9x9') {
      for (final edge in _consecutiveEdges) {
        final parts = edge.split(':');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        if (a == index && b == index + 1) {
          widgets.add(
            Positioned(
              right: -4,
              top: cellSize / 2 - 3,
              child: const Icon(Icons.circle, size: 6),
            ),
          );
        }
        if (a == index && b == index + 9) {
          widgets.add(
            Positioned(
              bottom: -4,
              left: cellSize / 2 - 3,
              child: const Icon(Icons.circle, size: 6),
            ),
          );
        }
      }
    }

    if (_variant == 'arrow_thermo_9x9') {
      for (final thermo in _thermos) {
        if (!thermo.contains(index)) continue;
        widgets.add(
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .14),
                    width: 3,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }
      for (final arrow in _arrows) {
        if (arrow.circle == index) {
          widgets.add(
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: cellSize * .55,
                    height: cellSize * .55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Center(
                      child: Text(
                        '${arrow.target}',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (arrow.path.contains(index)) {
          widgets.add(
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: .06),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSudoku) {
      final maxWidth = MediaQuery.sizeOf(context).width - 32;
      final boardSize = min<double>(
        widget.theme.boardSize,
        min<double>(maxWidth, _size == 25 ? 900 : 720),
      );
      final font = max(7.0, boardSize / (_size * 2.2));
      final cellSize = boardSize / _size;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.game.name} • $_variantLabel',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text(widget.difficulty)),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_variantDescription, style: const TextStyle(color: Colors.white60)),
              ),
              if (_variant == 'mega_25x25')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Symbols: 0–9 and A–O', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _size),
                  itemCount: _size * _size,
                  itemBuilder: (_, index) {
                    final value = _puzzle[index];
                    final given = _given[index];
                    final row = index ~/ _size;
                    final col = index % _size;
                    return InkWell(
                      onTap: given ? null : () => _showValuePicker(context, index),
                      child: Stack(
                        children: [
                          Positioned.fill(child: _cellDecoration(index, row, col, given)),
                          _variantOverlay(index, cellSize),
                          Positioned.fill(
                            child: Center(
                              child: value == 0
                                  ? const SizedBox.shrink()
                                  : Text(
                                      _symbol(value),
                                      style: TextStyle(
                                        fontSize: font,
                                        fontWeight: given ? FontWeight.w900 : FontWeight.w700,
                                        color: _variant == 'color_9x9' ? _colorForValue(value) : null,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('New puzzle')),
                  Text('$_moves moves', style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.construction_rounded, size: 52),
            const SizedBox(height: 12),
            Text('${widget.game.name} rules engine', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(
              'Difficulty: ${widget.difficulty}. Variant: ${GameCatalog.instance.variant(widget.game.id, widget.variant).name}. The catalog now supplies the game’s type and rules configuration.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyGamesScreen extends StatelessWidget {
  const DailyGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final daily = GameCatalog.definitions
        .where((game) => game.supportsDaily)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Daily Challenges'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: daily.length,
        itemBuilder: (_, index) {
          final game = daily[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.today_rounded),
              ),
              title: Text(
                game.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'One official daily puzzle, plus practice mode.',
              ),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => GameLaunchScreen(game: game),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
