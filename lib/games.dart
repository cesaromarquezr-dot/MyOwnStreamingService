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
    if (!game.isPlayable && !_catalogPlayableIds.contains(game.id)) {
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

  static const _mediaGameCategories = <GameCategory>{
    GameCategory.music,
    GameCategory.movieTv,
    GameCategory.danceRhythm,
  };

  static final _mediaGameIds = GameCatalog.definitions
      .where((game) => _mediaGameCategories.contains(game.category))
      .map((game) => game.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    var games = GameCatalog.definitions
        .where((game) => _mediaGameCategories.contains(game.category))
        .toList(growable: true);
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
            'Games built around your music, movies, and TV shows.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const UniversalText(
            'Play music, movie, and TV-themed games using media already in your server library. This section only shows these media-related game types.',
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
                for (final category in const <GameCategory>[
                  GameCategory.music,
                  GameCategory.movieTv,
                  GameCategory.danceRhythm,
                ]) ...[
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
                            if (!game.isPlayable && !_catalogPlayableIds.contains(game.id))
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
            ..._ratings.values
                .where((rating) => _mediaGameIds.contains(rating.gameId))
                .take(6)
                .map(
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
  int _mexicanTrainPlayerCount = 4;

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
      if (widget.game.id == 'mexican_train') {
        match['playerCount'] = _mexicanTrainPlayerCount;
        match['tilesPerPlayer'] = 17;
        match['doubleSet'] =
            _GamePlayCatalog.mexicanTrainSetFor(_mexicanTrainPlayerCount);
      }

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
          if (game.id == 'mexican_train') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _mexicanTrainPlayerCount,
              decoration: const InputDecoration(
                labelText: 'Players',
                prefixIcon: Icon(Icons.people_alt_outlined),
              ),
              items: List<DropdownMenuItem<int>>.generate(
                7,
                (index) => DropdownMenuItem<int>(
                  value: index + 2,
                  child: Text('${index + 2} players'),
                ),
              ),
              onChanged: _busy
                  ? null
                  : (value) => setState(
                        () => _mexicanTrainPlayerCount = value ?? 4,
                      ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Each player receives 17 dominoes. The set automatically expands beyond Double-12 when needed so every player gets a full rack and there is one central engine tile.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Selected set: Double-${_GamePlayCatalog.mexicanTrainSetFor(_mexicanTrainPlayerCount)}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700),
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

  /// Keeps a 17-tile rack for every player, reserving one tile for the hub.
  /// A Double-N set contains (N + 1) * (N + 2) / 2 unique tiles.
  static int mexicanTrainSetFor(int players) {
    var doubleValue = 12;
    while (((doubleValue + 1) * (doubleValue + 2) ~/ 2) <
        (players * 17 + 1)) {
      doubleValue++;
    }
    return doubleValue;
  }

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

    if (widget.game.id == 'checkers') {
      return CheckersGameBoard(
        theme: _theme,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'mexican_train') {
      return MexicanTrainGameBoard(
        mode: mode,
        playerCount: (widget.match['playerCount'] as num?)?.toInt() ?? 4,
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

    const tabletopGameIds = <String>{
      'connect4', 'solitaire', 'tripeaks', 'pyramid', 'freecell', 'spider',
      'continental', 'la_viuda',
    };
    if (tabletopGameIds.contains(widget.game.id)) {
      return TabletopGameBoard(
        game: widget.game,
        mode: mode,
        difficulty: difficulty,
        variant: variant,
        onFinished: _finishGame,
      );
    }

    if (_catalogPlayableIds.contains(widget.game.id)) {
      return CatalogGameBoard(
        game: widget.game,
        mode: mode,
        difficulty: difficulty,
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
  IconData _playerTokenIcon = Icons.directions_car_rounded;
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Text('Choose your token:'),
                  for (final token in <IconData>[Icons.directions_car_rounded, Icons.pets_rounded, Icons.sailing_rounded, Icons.rocket_launch_rounded, Icons.emoji_events_rounded, Icons.bolt_rounded])
                    IconButton(
                      tooltip: 'Select token',
                      visualDensity: VisualDensity.compact,
                      onPressed: _rolling || _finished ? null : () => setState(() => _playerTokenIcon = token),
                      style: IconButton.styleFrom(
                        backgroundColor: _playerTokenIcon == token ? Theme.of(context).colorScheme.primaryContainer : null,
                      ),
                      icon: Icon(token, size: 20),
                    ),
                ],
              ),
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
  final IconData _playerTokenIcon = Icons.directions_car_rounded;

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
                                if (player0) Icon(_playerTokenIcon, size: 17),
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
            Text('You: \$${_money[0]} • AI: \$${_money[1]}', style: const TextStyle(color: Colors.white60)),
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


class _CheckersPiece {
  final int side;
  bool king;

  _CheckersPiece(this.side) : king = false;
}

class _CheckersMove {
  final int from;
  final int to;
  final int? captured;

  const _CheckersMove(this.from, this.to, {this.captured});

  bool get isCapture => captured != null;
}

class CheckersGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const CheckersGameBoard({
    super.key,
    required this.theme,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<CheckersGameBoard> createState() => _CheckersGameBoardState();
}

class _CheckersGameBoardState extends State<CheckersGameBoard> {
  final Random _random = Random();
  late List<_CheckersPiece?> _board;
  int _turn = 0;
  int? _selected;
  int? _forcedFrom;
  int _redCaptures = 0;
  int _blackCaptures = 0;
  bool _thinking = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _board = _initialBoard();
  }

  List<_CheckersPiece?> _initialBoard() {
    final board = List<_CheckersPiece?>.filled(64, null);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) {
          board[row * 8 + col] = _CheckersPiece(1);
        }
      }
    }
    for (var row = 5; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isOdd) {
          board[row * 8 + col] = _CheckersPiece(0);
        }
      }
    }
    return board;
  }

  void _resetBoard() {
    setState(() {
      _board = _initialBoard();
      _turn = 0;
      _selected = null;
      _forcedFrom = null;
      _redCaptures = 0;
      _blackCaptures = 0;
      _thinking = false;
      _finished = false;
    });
  }

  int _row(int square) => square ~/ 8;
  int _col(int square) => square % 8;
  bool _inside(int row, int col) => row >= 0 && row < 8 && col >= 0 && col < 8;

  List<_CheckersMove> _movesForPiece(int from, int side, {bool capturesOnly = false}) {
    final piece = _board[from];
    if (piece == null || piece.side != side) return const <_CheckersMove>[];
    final row = _row(from);
    final col = _col(from);
    final directions = piece.king
        ? const <int>[-1, 1]
        : <int>[side == 0 ? -1 : 1];
    final captures = <_CheckersMove>[];
    final steps = <_CheckersMove>[];

    for (final dr in directions) {
      for (final dc in const <int>[-1, 1]) {
        final nextRow = row + dr;
        final nextCol = col + dc;
        if (!_inside(nextRow, nextCol)) continue;
        final nextIndex = nextRow * 8 + nextCol;
        final middle = _board[nextIndex];
        if (middle == null) {
          steps.add(_CheckersMove(from, nextIndex));
          continue;
        }
        if (middle.side == side) continue;
        final landingRow = row + dr * 2;
        final landingCol = col + dc * 2;
        if (!_inside(landingRow, landingCol)) continue;
        final landingIndex = landingRow * 8 + landingCol;
        if (_board[landingIndex] == null) {
          captures.add(_CheckersMove(from, landingIndex, captured: nextIndex));
        }
      }
    }

    if (capturesOnly) return captures;
    return captures.isNotEmpty ? captures : steps;
  }

  List<_CheckersMove> _allLegalMoves(int side) {
    final captures = <_CheckersMove>[];
    final normal = <_CheckersMove>[];
    for (var index = 0; index < 64; index++) {
      if (_board[index]?.side != side) continue;
      final moves = _movesForPiece(index, side);
      for (final move in moves) {
        if (move.isCapture) {
          captures.add(move);
        } else {
          normal.add(move);
        }
      }
    }
    return captures.isNotEmpty ? captures : normal;
  }

  _CheckersMove? _moveTo(Iterable<_CheckersMove> moves, int to) {
    for (final move in moves) {
      if (move.to == to) return move;
    }
    return null;
  }

  List<_CheckersMove> _selectedMoves() {
    if (_forcedFrom != null) {
      return _movesForPiece(_forcedFrom!, _turn, capturesOnly: true);
    }
    if (_selected == null) return const <_CheckersMove>[];
    final all = _allLegalMoves(_turn);
    return all.where((move) => move.from == _selected).toList(growable: false);
  }

  void _tapSquare(int index) {
    if (_finished || _thinking || (_turn == 1 && widget.mode == 'ai')) return;
    if (_forcedFrom != null) {
      final continuation = _movesForPiece(_forcedFrom!, _turn, capturesOnly: true);
      final selectedMove = _moveTo(continuation, index);
      if (selectedMove != null) _applyMove(selectedMove);
      return;
    }

    final targetMove = _moveTo(_selectedMoves(), index);
    if (targetMove != null) {
      _applyMove(targetMove);
      return;
    }

    final piece = _board[index];
    if (piece != null && piece.side == _turn) {
      final legal = _allLegalMoves(_turn).where((move) => move.from == index).toList();
      setState(() => _selected = legal.isEmpty ? null : index);
    } else {
      setState(() => _selected = null);
    }
  }

  void _applyMove(_CheckersMove move) {
    if (_finished) return;
    final piece = _board[move.from];
    if (piece == null) return;
    final rowAfter = _row(move.to);
    final becameKing = !piece.king &&
        ((piece.side == 0 && rowAfter == 0) || (piece.side == 1 && rowAfter == 7));

    setState(() {
      _board[move.to] = piece;
      _board[move.from] = null;
      if (move.captured != null) {
        _board[move.captured!] = null;
        if (_turn == 0) {
          _redCaptures++;
        } else {
          _blackCaptures++;
        }
      }
      if (becameKing) piece.king = true;
      _selected = null;
    });

    if (becameKing) {
      _endTurn();
      return;
    }

    if (move.isCapture) {
      final continuation = _movesForPiece(move.to, _turn, capturesOnly: true);
      if (continuation.isNotEmpty) {
        setState(() {
          _forcedFrom = move.to;
          _selected = move.to;
        });
        if (_turn == 1 && widget.mode == 'ai') _scheduleAiTurn();
        return;
      }
    }

    _endTurn();
  }

  void _endTurn() {
    if (_finished) return;
    final nextSide = 1 - _turn;
    final nextMoves = _allLegalMoves(nextSide);
    final hasPieces = _board.any((piece) => piece?.side == nextSide);
    if (!hasPieces || nextMoves.isEmpty) {
      setState(() {
        _finished = true;
        _selected = null;
        _forcedFrom = null;
      });
      widget.onFinished(nextSide == 0 ? 'loss' : 'win');
      return;
    }
    setState(() {
      _turn = nextSide;
      _selected = null;
      _forcedFrom = null;
    });
    if (_turn == 1 && widget.mode == 'ai') _scheduleAiTurn();
  }

  void _scheduleAiTurn() {
    if (!mounted || _finished || _thinking || _turn != 1 || widget.mode != 'ai') return;
    setState(() => _thinking = true);
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted || _finished || _turn != 1) return;
      final moves = _forcedFrom != null
          ? _movesForPiece(_forcedFrom!, 1, capturesOnly: true)
          : _allLegalMoves(1);
      if (moves.isEmpty) {
        setState(() => _thinking = false);
        _endTurn();
        return;
      }
      // Captures are mandatory. Prefer captures that crown a piece when choices exist.
      final preferred = moves.where((move) =>
          move.captured != null || _row(move.to) == 7).toList();
      final choicePool = preferred.isNotEmpty ? preferred : moves;
      final move = choicePool[_random.nextInt(choicePool.length)];
      setState(() => _thinking = false);
      _applyMove(move);
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 44;
    final boardSize = min<double>(widget.theme.boardSize, min<double>(availableWidth, 680));
    final legalMoves = _selectedMoves();
    final legalDestinations = legalMoves.map((move) => move.to).toSet();
    final redPieces = _board.where((piece) => piece?.side == 0).length;
    final blackPieces = _board.where((piece) => piece?.side == 1).length;
    final status = _finished
        ? 'Game finished'
        : _thinking
            ? 'Black AI is thinking…'
            : _forcedFrom != null
                ? (_turn == 0 ? 'Red: continue your capture' : 'Black: continue capture')
                : (_turn == 0 ? 'Red to move' : (widget.mode == 'ai' ? 'Black AI to move' : 'Black to move'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_3x3, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: 'Restart checkers',
                  onPressed: _thinking ? null : _resetBoard,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                Chip(avatar: const Icon(Icons.circle, color: Colors.redAccent, size: 14), label: Text('Red: $redPieces')),
                Chip(avatar: const Icon(Icons.circle, color: Colors.blueGrey, size: 14), label: Text('${widget.mode == 'ai' ? 'Black AI' : 'Black'}: $blackPieces')),
                Chip(label: Text('Captures: $_redCaptures - $_blackCaptures')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, index) {
                  final row = index ~/ 8;
                  final col = index % 8;
                  final piece = _board[index];
                  final selected = _selected == index;
                  final isLight = (row + col).isEven;
                  final isLegal = legalDestinations.contains(index);
                  return GestureDetector(
                    onTap: () => _tapSquare(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? widget.theme.accent.withValues(alpha: .8)
                            : isLegal
                                ? Colors.greenAccent.withValues(alpha: .36)
                                : isLight
                                    ? widget.theme.light
                                    : widget.theme.dark,
                        border: Border.all(color: Colors.black.withValues(alpha: .12), width: .3),
                      ),
                      child: Center(
                        child: piece != null
                            ? Container(
                                width: boardSize / 10.8,
                                height: boardSize / 10.8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: piece.side == 0 ? const Color(0xFFCD3434) : const Color(0xFF283746),
                                  border: Border.all(
                                    color: piece.side == 0 ? const Color(0xFFFFB7B7) : const Color(0xFFB9CBD9),
                                    width: max(1.5, boardSize / 180),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: piece.king
                                    ? Icon(Icons.star_rounded, size: boardSize / 17, color: Colors.amber)
                                    : null,
                              )
                            : isLegal
                                ? Container(
                                    width: boardSize / 36,
                                    height: boardSize / 36,
                                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _forcedFrom != null
                  ? 'You must finish the multiple jump with the selected piece.'
                  : 'Tap one of your pieces, then tap a highlighted square. Captures are mandatory; pieces become kings on the far row.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
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


class _MexicanDomino {
  final int a;
  final int b;

  const _MexicanDomino(this.a, this.b);

  bool matches(int value) => a == value || b == value;

  int? otherEnd(int value) {
    if (a == value) return b;
    if (b == value) return a;
    return null;
  }

  _MexicanDomino flipped() => _MexicanDomino(b, a);

}

class _MexicanTrainTarget {
  final String kind;
  final int owner;
  final int openEnd;
  final String label;

  const _MexicanTrainTarget({
    required this.kind,
    required this.owner,
    required this.openEnd,
    required this.label,
  });
}

class MexicanTrainGameBoard extends StatefulWidget {
  final String mode;
  final int playerCount;
  final Future<void> Function(String result) onFinished;

  const MexicanTrainGameBoard({
    super.key,
    required this.mode,
    required this.playerCount,
    required this.onFinished,
  });

  @override
  State<MexicanTrainGameBoard> createState() => _MexicanTrainGameBoardState();
}

class _MexicanTrainGameBoardState extends State<MexicanTrainGameBoard> {
  static const int _tilesPerPlayer = 17;
  final Random _random = Random();
  late int _doubleSet;
  late int _engineValue;
  late List<List<_MexicanDomino>> _hands;
  late List<_MexicanDomino> _boneyard;
  late List<List<_MexicanDomino>> _personalTrains;
  late List<int> _personalOpenEnds;
  late List<bool> _publicTrains;
  late List<_MexicanDomino> _mexicanTrain;
  int _mexicanOpenEnd = 12;
  int _currentPlayer = 0;
  int? _selectedTileIndex;
  int? _mustPlayDrawnTile;
  bool _aiThinking = false;
  bool _finished = false;
  String _status = 'Player 1 starts';

  int get _playerCount => widget.playerCount.clamp(2, 8).toInt();
  bool get _isHumanTurn => widget.mode != 'ai' || _currentPlayer == 0;

  @override
  void initState() {
    super.initState();
    _dealInitialHands();
  }

  void _dealInitialHands() {
    _doubleSet = _GamePlayCatalog.mexicanTrainSetFor(_playerCount);
    _engineValue = _doubleSet;
    final tiles = <_MexicanDomino>[];
    for (var a = 0; a <= _doubleSet; a++) {
      for (var b = a; b <= _doubleSet; b++) {
        tiles.add(_MexicanDomino(a, b));
      }
    }
    tiles.removeWhere((tile) => tile.a == _engineValue && tile.b == _engineValue);
    tiles.shuffle(_random);

    _hands = List<List<_MexicanDomino>>.generate(_playerCount, (_) => <_MexicanDomino>[]);
    for (var round = 0; round < _tilesPerPlayer; round++) {
      for (var player = 0; player < _playerCount; player++) {
        _hands[player].add(tiles.removeLast());
      }
    }
    _boneyard = tiles;
    _personalTrains = List<List<_MexicanDomino>>.generate(_playerCount, (_) => <_MexicanDomino>[]);
    _personalOpenEnds = List<int>.filled(_playerCount, _engineValue);
    _publicTrains = List<bool>.filled(_playerCount, false);
    _mexicanTrain = <_MexicanDomino>[];
    _mexicanOpenEnd = _engineValue;
    _currentPlayer = 0;
    _selectedTileIndex = null;
    _mustPlayDrawnTile = null;
    _aiThinking = false;
    _finished = false;
    _status = 'Player 1 starts. Match a $_engineValue end to start a train.';
  }

  void _restart() {
    setState(_dealInitialHands);
  }

  List<_MexicanTrainTarget> _targetsFor(_MexicanDomino tile, int player) {
    final targets = <_MexicanTrainTarget>[];
    if (tile.matches(_personalOpenEnds[player])) {
      targets.add(_MexicanTrainTarget(
        kind: 'personal',
        owner: player,
        openEnd: _personalOpenEnds[player],
        label: 'Player ${player + 1} train',
      ));
    }
    if (tile.matches(_mexicanOpenEnd)) {
      targets.add(_MexicanTrainTarget(
        kind: 'mexican',
        owner: -1,
        openEnd: _mexicanOpenEnd,
        label: 'Mexican Train',
      ));
    }
    for (var owner = 0; owner < _playerCount; owner++) {
      if (owner == player || !_publicTrains[owner]) continue;
      if (tile.matches(_personalOpenEnds[owner])) {
        targets.add(_MexicanTrainTarget(
          kind: 'personal',
          owner: owner,
          openEnd: _personalOpenEnds[owner],
          label: 'Player ${owner + 1} public train',
        ));
      }
    }
    return targets;
  }

  bool _hasAnyPlacement(int player) {
    for (final tile in _hands[player]) {
      if (_targetsFor(tile, player).isNotEmpty) return true;
    }
    return false;
  }

  List<_MexicanTrainTarget> get _selectedTargets {
    if (_selectedTileIndex == null || _selectedTileIndex! >= _hands[_currentPlayer].length) {
      return const <_MexicanTrainTarget>[];
    }
    return _targetsFor(_hands[_currentPlayer][_selectedTileIndex!], _currentPlayer);
  }

  void _selectTile(int index) {
    if (_finished || _aiThinking || !_isHumanTurn) return;
    if (_mustPlayDrawnTile != null && index != _mustPlayDrawnTile) return;
    setState(() {
      _selectedTileIndex = index == _selectedTileIndex ? null : index;
      _status = _selectedTileIndex == null
          ? 'Select a domino to play.'
          : 'Choose a train that matches one end of the selected domino.';
    });
  }

  void _playSelectedOn(_MexicanTrainTarget target) {
    if (_finished || !_isHumanTurn || _selectedTileIndex == null) return;
    _playTile(_currentPlayer, _selectedTileIndex!, target);
  }

  void _playTile(int player, int handIndex, _MexicanTrainTarget target) {
    if (_finished || handIndex < 0 || handIndex >= _hands[player].length) return;
    final tile = _hands[player][handIndex];
    final nextOpen = tile.otherEnd(target.openEnd);
    if (nextOpen == null) return;

    setState(() {
      _hands[player].removeAt(handIndex);
      if (_mustPlayDrawnTile != null) _mustPlayDrawnTile = null;
      if (target.kind == 'mexican') {
        _mexicanTrain.add(tile.a == target.openEnd ? tile : tile.flipped());
        _mexicanOpenEnd = nextOpen;
      } else {
        _personalTrains[target.owner].add(
          tile.a == target.openEnd ? tile : tile.flipped(),
        );
        _personalOpenEnds[target.owner] = nextOpen;
        if (target.owner == player) _publicTrains[player] = false;
      }
      _selectedTileIndex = null;
      _status = 'Player ${player + 1} played ${tile.a}|${tile.b} on ${target.label}.';
    });

    if (_hands[player].isEmpty) {
      _finishRound(player);
      return;
    }
    _advanceTurn();
  }

  void _finishRound(int winner) {
    if (_finished) return;
    setState(() {
      _finished = true;
      _selectedTileIndex = null;
      _mustPlayDrawnTile = null;
      _status = winner == 0 ? 'You emptied your rack and won the round!' : 'Player ${winner + 1} emptied their rack.';
    });
    widget.onFinished(winner == 0 ? 'win' : 'loss');
  }

  void _advanceTurn() {
    if (_finished) return;
    setState(() {
      _currentPlayer = (_currentPlayer + 1) % _playerCount;
      _selectedTileIndex = null;
      _mustPlayDrawnTile = null;
      _status = widget.mode == 'ai' && _currentPlayer != 0
          ? 'Player ${_currentPlayer + 1} AI is thinking…'
          : 'Player ${_currentPlayer + 1} to play.';
    });
    if (widget.mode == 'ai' && _currentPlayer != 0) _scheduleAiTurn();
  }

  void _drawOrPass() {
    if (_finished || _aiThinking || !_isHumanTurn || _hasAnyPlacement(_currentPlayer)) return;
    if (_boneyard.isNotEmpty) {
      final drawn = _boneyard.removeLast();
      final drawnIndex = _hands[_currentPlayer].length;
      setState(() {
        _hands[_currentPlayer].add(drawn);
        _selectedTileIndex = drawnIndex;
        _mustPlayDrawnTile = _drawnHasPlacement(drawn, _currentPlayer) ? drawnIndex : null;
        _status = _mustPlayDrawnTile != null
            ? 'You drew ${drawn.a}|${drawn.b}. Play this domino now.'
            : 'No playable domino. Your train is now public; turn passed.';
      });
      if (_mustPlayDrawnTile == null) {
        setState(() {
          _publicTrains[_currentPlayer] = true;
          _selectedTileIndex = null;
        });
        _advanceTurn();
      }
    } else {
      setState(() {
        _publicTrains[_currentPlayer] = true;
        _selectedTileIndex = null;
        _mustPlayDrawnTile = null;
        _status = 'Boneyard empty. Player ${_currentPlayer + 1} passes and their train is public.';
      });
      _advanceTurn();
    }
  }

  bool _drawnHasPlacement(_MexicanDomino tile, int player) =>
      _targetsFor(tile, player).isNotEmpty;

  void _scheduleAiTurn() {
    if (!mounted || _finished || _aiThinking || widget.mode != 'ai' || _currentPlayer == 0) return;
    setState(() => _aiThinking = true);
    Future<void>.delayed(const Duration(milliseconds: 480), () {
      if (!mounted || _finished || _currentPlayer == 0) return;
      final player = _currentPlayer;
      var chosenIndex = -1;
      _MexicanTrainTarget? chosenTarget;
      for (var index = 0; index < _hands[player].length; index++) {
        final targets = _targetsFor(_hands[player][index], player);
        if (targets.isNotEmpty) {
          chosenIndex = index;
          chosenTarget = targets.first;
          break;
        }
      }
      setState(() => _aiThinking = false);
      if (chosenIndex >= 0 && chosenTarget != null) {
        _playTile(player, chosenIndex, chosenTarget);
        return;
      }

      if (_boneyard.isNotEmpty) {
        final tile = _boneyard.removeLast();
        final index = _hands[player].length;
        setState(() => _hands[player].add(tile));
        final targets = _targetsFor(tile, player);
        if (targets.isNotEmpty) {
          _playTile(player, index, targets.first);
          return;
        }
      }
      setState(() {
        _publicTrains[player] = true;
        _status = 'Player ${player + 1} AI passed; their train is public.';
      });
      _advanceTurn();
    });
  }

  Widget _pipHalf(int count, {double side = 34}) {
    final cells = count <= 9 ? 9 : 16;
    final columns = count <= 9 ? 3 : 4;
    final dotSize = count <= 9 ? 4.4 : 3.2;
    return SizedBox(
      width: side,
      height: side,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
        ),
        itemCount: cells,
        itemBuilder: (context, index) => index < count
            ? Center(
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(color: Color(0xFF15202B), shape: BoxShape.circle),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _dominoFace(_MexicanDomino tile, {bool selected = false, double width = 74, double height = 40}) {
    final half = (width - 8) / 2;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? Colors.amber : const Color(0xFFB3A58A),
          width: selected ? 3 : 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pipHalf(tile.a, side: min<double>(half, height - 4)),
          Container(width: 1.5, height: height - 6, color: const Color(0xFFB3A58A)),
          _pipHalf(tile.b, side: min<double>(half, height - 4)),
        ],
      ),
    );
  }

  Widget _dominoBack({double width = 16, double height = 27}) => Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF234D73),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF9FC5E8)),
        ),
        child: Center(
          child: Container(
            width: width * .42,
            height: height * .58,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: .8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _trainRow(List<_MexicanDomino> train, int startValue, {bool compact = false}) {
    var open = startValue;
    final children = <Widget>[];
    for (final tile in train) {
      final oriented = tile.a == open ? tile : tile.flipped();
      children.add(_dominoFace(oriented, width: compact ? 55 : 67, height: compact ? 31 : 36));
      children.add(const SizedBox(width: 4));
      open = oriented.b;
    }
    if (children.isEmpty) {
      children.add(const Text('No dominoes played yet', style: TextStyle(color: Colors.white38, fontSize: 12)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  Widget _playerRackSummary(int player) {
    final isCurrent = player == _currentPlayer;
    final isAi = widget.mode == 'ai' && player > 0;
    final label = player == 0 ? 'You' : isAi ? 'Player ${player + 1} · AI' : 'Player ${player + 1}';
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.amber.withValues(alpha: .10) : Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? Colors.amber : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${_hands[player].length} dominoes${_publicTrains[player] ? ' · train public' : ''}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          if (isCurrent && _isHumanTurn)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var index = 0; index < _hands[player].length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _dominoBack(width: 12, height: 22),
                  ),
              ]),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (var i = 0; i < _hands[player].length; i++) _dominoBack(width: 10, height: 22)]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTiles = (_doubleSet + 1) * (_doubleSet + 2) ~/ 2;
    final openTargets = _selectedTargets;
    final humanTurn = _isHumanTurn && !_aiThinking && !_finished;
    final canDraw = humanTurn && !_hasAnyPlacement(_currentPlayer) && _mustPlayDrawnTile == null;
    final width = min<double>(MediaQuery.sizeOf(context).width - 56, 760);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_week_outlined, size: 28),
                const SizedBox(width: 8),
                const Expanded(child: Text('Mexican Train', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                IconButton(tooltip: 'Restart round', onPressed: _aiThinking ? null : _restart, icon: const Icon(Icons.restart_alt_rounded)),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(label: Text('Double-$_doubleSet set · $totalTiles tiles')),
                const Chip(label: Text('17 starting tiles each')),
                Chip(label: Text('${_boneyard.length} in boneyard')),
              ],
            ),
            const SizedBox(height: 8),
            Text(_status, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Card(
              color: Colors.blueGrey.withValues(alpha: .15),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Central hub / engine', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _dominoFace(_MexicanDomino(_engineValue, _engineValue), width: 74, height: 40),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Double-$_engineValue is the starting value for every train.', style: const TextStyle(color: Colors.white60, fontSize: 12))),
                    ]),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Text('Mexican Train · public', style: TextStyle(fontWeight: FontWeight.w800))),
                      Chip(label: Text('Open: $_mexicanOpenEnd')),
                    ]),
                    const SizedBox(height: 8),
                    _trainRow(_mexicanTrain, _engineValue),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Text('Players’ personal trains', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            for (var player = 0; player < _playerCount; player++)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text('Player ${player + 1}${player == 0 ? ' · You' : widget.mode == 'ai' ? ' · AI' : ''}${_publicTrains[player] ? ' · PUBLIC' : ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        Chip(label: Text('Open: ${_personalOpenEnds[player]}')),
                      ]),
                      _trainRow(_personalTrains[player], _engineValue, compact: true),
                    ],
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Text('Every player’s rack', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            SizedBox(
              width: width,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var player = 0; player < _playerCount; player++)
                      Padding(padding: const EdgeInsets.only(right: 8), child: _playerRackSummary(player)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.withValues(alpha: .06),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentPlayer == 0 ? 'Your domino rack · ${_hands[0].length} tiles' : 'Player ${_currentPlayer + 1} rack · ${_hands[_currentPlayer].length} tiles', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var index = 0; index < _hands[_currentPlayer].length; index++)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: humanTurn
                                  ? InkWell(
                                      onTap: () => _selectTile(index),
                                      borderRadius: BorderRadius.circular(8),
                                      child: _dominoFace(
                                        _hands[_currentPlayer][index],
                                        selected: index == _selectedTileIndex,
                                      ),
                                    )
                                  : _dominoBack(width: 25, height: 40),
                            ),
                        ],
                      ),
                    ),
                    if (openTargets.isNotEmpty && humanTurn) ...[
                      const SizedBox(height: 12),
                      const Text('Play selected domino on:', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final target in openTargets)
                            FilledButton.tonal(
                              onPressed: () => _playSelectedOn(target),
                              child: Text('${target.label} (open ${target.openEnd})'),
                            ),
                        ],
                      ),
                    ] else if (_selectedTileIndex != null && humanTurn) ...[
                      const SizedBox(height: 8),
                      const Text('That domino does not match an available train. Select another tile or draw if you have no legal play.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: canDraw ? _drawOrPass : null,
                        icon: const Icon(Icons.add_box_outlined),
                        label: Text(_boneyard.isEmpty ? 'Pass (boneyard empty)' : 'Draw 1 domino / pass'),
                      ),
                    ),
                    if (_mustPlayDrawnTile != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('You must play the drawn tile before ending your turn.', style: TextStyle(color: Colors.amber, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            const Text(
              'Local play includes the visual hub, personal trains, public-train markers, matching ends, draw/pass, and 17-tile racks. The Double-N set expands for larger player counts so all racks fit.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated playable layouts for Connect 4 and the requested card-table games.
class TabletopGameBoard extends StatefulWidget {
  final GameDefinition game;
  final String mode;
  final String difficulty;
  final String variant;
  final Future<void> Function(String result) onFinished;

  const TabletopGameBoard({
    super.key,
    required this.game,
    required this.mode,
    required this.difficulty,
    required this.variant,
    required this.onFinished,
  });

  @override
  State<TabletopGameBoard> createState() => _TabletopGameBoardState();
}

class _TabletopGameBoardState extends State<TabletopGameBoard> {
  final Random _random = Random();
  final List<int> _connectCells = List<int>.filled(42, 0);
  final List<String> _deck = <String>[];
  final List<String> _waste = <String>[];
  final List<String> _hand = <String>[];
  final List<String> _layoutCards = <String>[];
  final Set<int> _removed = <int>{};
  int _turn = 1;
  int _moves = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;

  String get _id => widget.game.id;
  bool get _connect4 => _id == 'connect4';
  bool get _rummy => _id == 'continental' || _id == 'la_viuda';
  bool get _solo => !_connect4 && !_rummy;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _connectCells.fillRange(0, _connectCells.length, 0);
    _deck.clear();
    _waste.clear();
    _hand.clear();
    _layoutCards.clear();
    _removed.clear();
    _turn = 1;
    _moves = 0;
    _score = 0;
    _selected = null;
    _finished = false;
    if (_rummy) {
      _hand.addAll(List<String>.generate(7, (_) => _drawCardLabel()));
      _deck.addAll(List<String>.generate(40, (_) => _drawCardLabel()));
      _waste.add(_drawCardLabel());
    } else if (_solo) {
      final count = _id == 'spider' ? 104 : 52;
      _deck.addAll(List<String>.generate(count, (_) => _drawCardLabel()));
      _deck.shuffle(_random);
      final layoutCount = _id == 'spider' ? 54 : _id == 'freecell' ? 52 : 28;
      for (var i = 0; i < layoutCount && _deck.isNotEmpty; i++) {
        _layoutCards.add(_deck.removeLast());
      }
      if (_id == 'tripeaks' && _deck.isNotEmpty) {
        _waste.add(_deck.removeLast());
      }
    }
  }

  String _drawCardLabel() {
    const ranks = <String>['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = <String>['♠', '♥', '♦', '♣'];
    return '${ranks[_random.nextInt(ranks.length)]}${suits[_random.nextInt(suits.length)]}';
  }

  bool _hasConnectFour(int row, int col, int player) {
    const directions = <List<int>>[[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final direction in directions) {
      var count = 1;
      for (final sign in <int>[-1, 1]) {
        var r = row + direction[0] * sign;
        var c = col + direction[1] * sign;
        while (r >= 0 && r < 6 && c >= 0 && c < 7 && _connectCells[r * 7 + c] == player) {
          count++;
          r += direction[0] * sign;
          c += direction[1] * sign;
        }
      }
      if (count >= 4) return true;
    }
    return false;
  }

  Future<void> _drop(int col) async {
    if (_finished || _turn != 1) return;
    final row = List<int>.generate(6, (i) => 5 - i).firstWhere(
      (r) => _connectCells[r * 7 + col] == 0,
      orElse: () => -1,
    );
    if (row < 0) return;
    setState(() {
      _connectCells[row * 7 + col] = 1;
      _moves++;
    });
    if (_hasConnectFour(row, col, 1)) {
      setState(() => _finished = true);
      await widget.onFinished('win');
      return;
    }
    if (_connectCells.every((cell) => cell != 0)) {
      setState(() => _finished = true);
      await widget.onFinished('draw');
      return;
    }
    setState(() => _turn = 2);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || _finished) return;
    final columns = List<int>.generate(7, (i) => i)..shuffle(_random);
    for (final aiCol in columns) {
      final aiRow = List<int>.generate(6, (i) => 5 - i).firstWhere(
        (r) => _connectCells[r * 7 + aiCol] == 0,
        orElse: () => -1,
      );
      if (aiRow >= 0) {
        setState(() {
          _connectCells[aiRow * 7 + aiCol] = 2;
          _moves++;
          _turn = 1;
        });
        if (_hasConnectFour(aiRow, aiCol, 2)) {
          setState(() => _finished = true);
          await widget.onFinished('loss');
        } else if (_connectCells.every((cell) => cell != 0)) {
          setState(() => _finished = true);
          await widget.onFinished('draw');
        }
        break;
      }
    }
  }

  void _drawStock() {
    if (_finished) return;
    setState(() {
      if (_deck.isEmpty) {
        if (_waste.isNotEmpty) {
          _deck.addAll(_waste.reversed.toList());
          _waste.clear();
        }
      }
      if (_deck.isNotEmpty) {
        final card = _deck.removeLast();
        if (_rummy) {
          _hand.add(card);
        } else {
          _waste.add(card);
        }
        _moves++;
        _selected = null;
      }
    });
  }

  void _tapCard(int index, String card) {
    if (_finished) return;
    setState(() {
      if (_rummy) {
        _selected = _selected == index ? null : index;
        return;
      }
      if (_id == 'pyramid') {
        if (_selected == null) {
          _selected = index;
        } else {
          final first = _selected!;
          final firstRank = _rankValue(_soloCardAt(first));
          final secondRank = _rankValue(card);
          if (first != index && firstRank + secondRank == 13) {
            _removed.add(first);
            _removed.add(index);
            _score += 10;
            _moves++;
            _selected = null;
          } else {
            _selected = index;
          }
        }
      } else if (_id == 'tripeaks') {
        if (_waste.isEmpty || _adjacentRank(card, _waste.last)) {
          _removed.add(index);
          _waste.add(card);
          _score += 5;
          _moves++;
        } else {
          _selected = index;
        }
      } else {
        if (_selected == null) {
          _selected = index;
        } else if (_selected != index) {
          _removed.add(_selected!);
          _removed.add(index);
          _score += 5;
          _moves++;
          _selected = null;
        } else {
          _selected = null;
        }
      }
      final total = _id == 'pyramid' ? 28 : _id == 'tripeaks' ? 28 : _id == 'spider' ? 54 : 28;
      if (_removed.length >= total) _finished = true;
    });
  }

  String _soloCardAt(int index) {
    if (index < 0 || index >= _soloLayoutCards.length) return 'K♠';
    return _soloLayoutCards[index];
  }

  List<String> get _soloLayoutCards => _layoutCards;

  int _rankValue(String card) {
    final rank = card.replaceAll(RegExp(r'[^0-9AJQK]'), '');
    if (rank == 'A') return 1;
    if (rank == 'J') return 11;
    if (rank == 'Q') return 12;
    if (rank == 'K') return 13;
    return int.tryParse(rank) ?? 0;
  }

  bool _adjacentRank(String a, String b) {
    final difference = (_rankValue(a) - _rankValue(b)).abs();
    return difference == 1 || difference == 12;
  }

  @override
  Widget build(BuildContext context) {
    if (_connect4) return _buildConnect4();
    if (_rummy) return _buildRummy();
    return _buildSolitaire();
  }

  Widget _buildConnect4() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _statusCard('CONNECT 4', 'Drop a disc into a column. Connect four horizontally, vertically or diagonally.', 'Turn: ${_turn == 1 ? 'You' : 'AI'}  •  Moves: $_moves'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF174EA6), borderRadius: BorderRadius.circular(18)),
        child: Column(children: List<Widget>.generate(6, (row) => Row(children: List<Widget>.generate(7, (col) {
          final value = _connectCells[row * 7 + col];
          return Expanded(child: AspectRatio(aspectRatio: 1, child: Padding(padding: const EdgeInsets.all(3), child: Material(
            color: value == 1 ? const Color(0xFFF44336) : value == 2 ? const Color(0xFFFFD54F) : const Color(0xFFEAF1FA),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: () => _drop(col), child: const SizedBox.expand()),
          ))));
        })))),
      ),
      const SizedBox(height: 12),
      _actionRow('New game', Icons.refresh, _resetAndRefresh, 'Tap any column to drop your red disc.'),
    ]);
  }

  Widget _buildSolitaire() {
    final title = widget.game.name;
    final cards = _soloLayoutCards;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _statusCard(title.toUpperCase(), _rulesForSolo(), 'Moves: $_moves  •  Score: $_score  •  Stock: ${_deck.length}'),
      const SizedBox(height: 12),
      if (_id == 'pyramid') _buildPyramid(cards)
      else if (_id == 'tripeaks') _buildTriPeaks(cards)
      else if (_id == 'freecell') _buildFreeCell(cards)
      else if (_id == 'spider') _buildSpider(cards)
      else _buildTableau(cards),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _drawStock, icon: const Icon(Icons.style), label: Text(_id == 'tripeaks' ? 'Draw / pass' : 'Draw card'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(onPressed: _resetAndRefresh, icon: const Icon(Icons.refresh), label: const Text('New deal'))),
      ]),
      const SizedBox(height: 8),
      Text(_id == 'pyramid' ? 'Select two exposed cards that total 13. Kings can be removed alone.' : _id == 'tripeaks' ? 'Remove exposed cards one rank above or below the waste card.' : _id == 'freecell' ? 'Use the four free cells as temporary storage; build foundations by suit from Ace to King.' : _id == 'spider' ? 'Build descending sequences. Complete King-to-Ace runs to clear a suit.' : 'Select a card, then another card to move/remove it. Use stock to reveal more cards.', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  String _rulesForSolo() => switch (_id) {
    'solitaire' => 'Klondike layout: build foundations from Ace to King, alternating colors in descending tableau columns.',
    'tripeaks' => 'Clear three peaks by playing an exposed card one rank above or below the waste card.',
    'pyramid' => 'Pair exposed cards whose ranks add to 13 to clear the pyramid.',
    'freecell' => 'Move every card to the four suit foundations. Four free cells can hold one card each.',
    'spider' => 'Build descending same-suit sequences and clear complete King-to-Ace runs.',
    _ => 'Select cards and build valid sequences to clear the layout.',
  };

  Widget _buildTableau(List<String> cards) {
    final columns = _id == 'freecell' ? 8 : _id == 'spider' ? 10 : 7;
    return Column(children: [
      if (_id == 'freecell') _specialSlots('FREE CELLS', 4),
      if (_id == 'solitaire') _specialSlots('FOUNDATIONS', 4),
      const SizedBox(height: 8),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: columns, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 4, mainAxisSpacing: 6, childAspectRatio: .66), itemBuilder: (context, col) {
        final index = col;
        final card = cards[index];
        return Column(children: [
          _playingCard(card, onTap: () => _tapCard(index, card), selected: _selected == index, removed: _removed.contains(index)),
          const SizedBox(height: 4),
          for (var row = 1; row < 3 && col + row * columns < cards.length; row++)
            Padding(padding: const EdgeInsets.only(top: 3), child: _playingCard(cards[col + row * columns], onTap: () => _tapCard(col + row * columns, cards[col + row * columns]), selected: _selected == col + row * columns, removed: _removed.contains(col + row * columns))),
        ]);
      }),
    ]);
  }

  Widget _buildFreeCell(List<String> cards) => Column(children: [
    _specialSlots('FREE CELLS', 4), const SizedBox(height: 8), _specialSlots('FOUNDATIONS', 4), const SizedBox(height: 12),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 8, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, crossAxisSpacing: 4, childAspectRatio: .62), itemBuilder: (context, i) => _playingCard(cards[i], onTap: () => _tapCard(i, cards[i]), selected: _selected == i, removed: _removed.contains(i))),
  ]);

  Widget _buildSpider(List<String> cards) => Column(children: [
    _specialSlots('COMPLETED RUNS  •  ${_score ~/ 100}', 8), const SizedBox(height: 10),
    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 10, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 3, childAspectRatio: .58), itemBuilder: (context, i) => Column(children: [for (var r = 0; r < 4; r++) Padding(padding: const EdgeInsets.only(bottom: 3), child: _playingCard(cards[(i * 4 + r) % cards.length], onTap: () => _tapCard(i * 4 + r, cards[(i * 4 + r) % cards.length]), selected: _selected == i * 4 + r, removed: _removed.contains(i * 4 + r))) ])),
  ]);

  Widget _buildPyramid(List<String> cards) => Column(children: List<Widget>.generate(7, (row) => Row(mainAxisAlignment: MainAxisAlignment.center, children: List<Widget>.generate(row + 1, (col) {
    final index = row * (row + 1) ~/ 2 + col;
    final card = cards[index];
    final covered = row < 6 && (_removed.contains(index + row + 1) == false || _removed.contains(index + row + 2) == false);
    return Padding(padding: const EdgeInsets.all(2), child: SizedBox(width: 39, child: Opacity(opacity: _removed.contains(index) ? .18 : 1, child: _playingCard(card, onTap: covered ? null : () => _tapCard(index, card), selected: _selected == index, removed: _removed.contains(index)))));
  }))));

  Widget _buildTriPeaks(List<String> cards) => Column(children: [
    for (var row = 0; row < 3; row++) Row(mainAxisAlignment: MainAxisAlignment.center, children: List<Widget>.generate(3 + row * 2, (col) {
      final index = row * 9 + col;
      final card = cards[index % cards.length];
      return SizedBox(width: 38, child: Padding(padding: const EdgeInsets.all(2), child: _playingCard(card, onTap: row == 2 ? () => _tapCard(index, card) : null, selected: _selected == index, removed: _removed.contains(index))));
    })),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _playingCard(_deck.isEmpty ? '↻' : '▧', onTap: _drawStock), const SizedBox(width: 16),
      _playingCard(_waste.isEmpty ? '—' : _waste.last, onTap: _waste.isEmpty ? null : () => _tapCard(27, _waste.last)),
    ]),
  ]);

  Widget _specialSlots(String label, int count) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 5),
          Row(
            children: List<Widget>.generate(
              count,
              (i) => Expanded(
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4D3B),
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      i < _waste.length && label == 'FOUNDATIONS' ? _waste[i] : '＋',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _playingCard(String label, {VoidCallback? onTap, bool selected = false, bool removed = false}) {
    final red = label.contains('♥') || label.contains('♦');
    return Opacity(
      opacity: removed ? .2 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0B3) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.amber : const Color(0xFFCFD5DE),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: red ? const Color(0xFFD32F2F) : const Color(0xFF202633),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRummy() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _statusCard(_id == 'continental' ? 'CONTINENTAL RUMMY' : 'LA VIUDA', _id == 'continental' ? 'Draw from the stock or take the discard, then discard one card. Form the required sets and runs for each round.' : 'Card-table mode: draw, arrange your hand, and discard. Local rule sets can vary by region.', 'Your hand: ${_hand.length} cards  •  Deck: ${_deck.length}  •  Turn: You'),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF14543F), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 10),
      Row(children: [Expanded(child: _playingCard(_deck.isEmpty ? '↻' : '▧', onTap: _drawStock)), const SizedBox(width: 12), Expanded(child: _playingCard(_waste.isEmpty ? '—' : _waste.last, onTap: () { if (_waste.isNotEmpty) setState(() => _hand.add(_waste.removeLast())); }))]),
      const SizedBox(height: 8), const Text('Tap stock to draw • tap discard pile to take its top card', style: TextStyle(color: Colors.white70, fontSize: 12)),
    ])),
    const SizedBox(height: 12),
    Text('YOUR HAND (${_hand.length})', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 6),
    Wrap(
      spacing: 6,
      runSpacing: 8,
      children: List<Widget>.generate(
        _hand.length,
        (i) => SizedBox(
          width: 47,
          height: 66,
          child: _playingCard(
            _hand[i],
            selected: _selected == i,
            onTap: () => setState(() => _selected = _selected == i ? null : i),
          ),
        ),
      ),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _hand.isEmpty ? null : () { setState(() { final i = _selected ?? _hand.length - 1; _waste.add(_hand.removeAt(i)); _selected = null; _moves++; }); }, icon: const Icon(Icons.output), label: const Text('Discard selected card')),
    const SizedBox(height: 8), Text(_id == 'continental' ? 'Continental rounds commonly require combinations such as sets and runs; confirm your house rules before a scored multiplayer match.' : 'La Viuda has regional rule differences. This table currently supports drawing, hand selection and discarding; full scoring should follow the chosen local rules.', style: Theme.of(context).textTheme.bodySmall),
  ]);

  Widget _statusCard(String title, String subtitle, String stats) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle), const SizedBox(height: 8), Text(stats, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))])));

  Widget _actionRow(String label, IconData icon, VoidCallback action, String helper) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [OutlinedButton.icon(onPressed: action, icon: Icon(icon), label: Text(label)), Text(helper, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]);

  void _resetAndRefresh() => setState(_resetGame);
}




// Catalog-driven visual boards for the remaining games. Each game gets a
// category-specific play surface and game-specific instructions while keeping
// the existing match lifecycle and result callback.
const Set<String> _catalogPlayableIds = <String>{
  'battleship',
  'uno_like',
  'texas_holdem',
  'blackjack',
  'baccarat',
  'mahjong',
  'word_search',
  'minesweeper',
  'snake',
  'bubble',
  'bejeweled_like',
  'gravity_block',
  'gem_drop',
  'queens',
  'tango',
  'patches',
  'zip',
  'wend',
  'pinpoint',
  'crossclimb',
  'dominoes',
  'draw_dominoes',
  'all_fives',
  'chicken_foot',
  'rummikub',
  'reversi',
  'gomoku',
  'tic_tac_toe',
  'mancala',
  'chinese_checkers',
  'hearts',
  'spades',
  'crazy_eights',
  'go_fish',
  'war',
  'gin_rummy',
  'rummy',
  'old_maid',
  'pool',
  'bowling',
  'darts',
  'mini_golf',
  'air_hockey',
  'pinball',
  'endless_runner',
  'maze_chase',
  'brick_breaker',
  'reaction_race',
  'memory_match',
  'simon_says',
  'pattern_memory',
  'quick_math',
  'number_guess',
  'twenty_questions',
  'hangman',
  'word_scramble',
  'word_ladder',
  'anagrams',
  'word_association',
  'categories',
  'word_chain',
  'spell_it',
  'password',
  'taboo_style',
  'charades',
  'pictionary',
  'draw_and_guess',
  'emoji_pictionary',
  'emoji_movie',
  'emoji_song',
  'guess_song',
  'guess_artist',
  'guess_album',
  'guess_genre',
  'guess_decade',
  'guess_year',
  'guess_music_video',
  'guess_instrument',
  'guess_cover_artist',
  'guess_original',
  'one_second_song',
  'three_second_song',
  'five_second_song',
  'ten_second_song',
  'first_note',
  'first_beat',
  'first_word',
  'fastest_guess',
  'finish_lyrics',
  'missing_lyrics',
  'next_word',
  'next_line',
  'lyrics_scramble',
  'who_sang_line',
  'lyrics_multiple_choice',
  'wrong_lyrics',
  'continue_song',
  'music_timeline',
  'which_song_first',
  'higher_lower_year',
  'higher_lower_streams',
  'artist_vs_artist',
  'album_vs_album',
  'guess_sample',
  'name_that_cover',
  'one_hit_wonder',
  'music_connections',
  'song_battle',
  'best_intro',
  'best_chorus',
  'best_bassline',
  'best_guitar',
  'best_party_song',
  'best_workout_song',
  'best_movie_song',
  'best_song_decade',
  'guess_movie',
  'guess_tv_show',
  'guess_actor',
  'guess_actress',
  'guess_character',
  'guess_director',
  'guess_franchise',
  'guess_episode',
  'guess_scene',
  'guess_location',
  'movie_soundtrack_guess',
  'tv_theme_guess',
  'movie_quote',
  'tv_quote',
  'who_said_it',
  'movie_sound_effect',
  'show_sound_effect',
  'blurred_scene',
  'zoomed_scene',
  'pixelated_movie',
  'silhouette_character',
  'actor_face',
  'movie_poster_puzzle',
  'missing_poster',
  'movie_trivia',
  'tv_trivia',
  'release_year',
  'actor_connections',
  'director_connections',
  'movie_timeline',
  'sequel_or_original',
  'remake_or_original',
  'movie_or_tv',
  'which_movie_first',
  'box_office_higher_lower',
  'runtime_higher_lower',
  'tv_show_emoji',
  'family_feud',
  'survey_says',
  'most_likely_to',
  'would_you_rather',
  'never_have_i_ever',
  'two_truths_lie',
  'truth_or_bluff',
  'guess_who',
  'hot_seat',
  'whos_most_likely',
  'act_it_out',
  'sound_effects',
  'impression_challenge',
  'dance_challenge',
  'lip_sync_battle',
  'karaoke_battle',
  'music_racing',
  'beat_saber_style',
  'dance_coach',
  'rhythm_challenge',
  'dance_battle',
  'motion_sports',
  'cross_game_tournament',
  'crossover_arena_fighter',
};

class CatalogGameBoard extends StatefulWidget {
  final GameDefinition game;
  final String mode;
  final String difficulty;
  final Future<void> Function(String result) onFinished;

  const CatalogGameBoard({
    super.key,
    required this.game,
    required this.mode,
    required this.difficulty,
    required this.onFinished,
  });

  @override
  State<CatalogGameBoard> createState() => _CatalogGameBoardState();
}

class _CatalogGameBoardState extends State<CatalogGameBoard> {
  final Random _random = Random();
  final TextEditingController _answerController = TextEditingController();
  late List<int> _cells;
  late List<String> _hand;
  late List<String> _options;
  int _selected = -1;
  int _score = 0;
  int _round = 1;
  int _turn = 0;
  int _moves = 0;
  bool _finished = false;
  String _status = 'Choose a move to begin.';

  String get _id => widget.game.id;
  String get _category => widget.game.category.name;
  bool get _isCard => _category == 'card' || _category == 'casinoPlayMoney';
  bool get _isBoard => _category == 'board' || _category == 'tile' || _category == 'dominoes';
  bool get _isWord => _category == 'word' || _category == 'trivia' || _category == 'music' || _category == 'movieTv';
  bool get _isArcade => _category == 'arcade' || _category == 'sports' || _category == 'racing' || _category == 'danceRhythm' || _category == 'fighting';
  bool get _isParty => _category == 'party' || _category == 'tournament';
  bool get _isGridPuzzle => _category == 'puzzle';

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _reset() {
    _cells = List<int>.filled(_id == 'tic_tac_toe' ? 9 : _id == 'gomoku' || _id == 'reversi' ? 64 : 25, 0);
    _hand = List<String>.generate(_id == 'spades' || _id == 'hearts' ? 13 : 7, (_) => _randomCard());
    _options = _makeOptions();
    _selected = -1;
    _score = 0;
    _round = 1;
    _turn = 0;
    _moves = 0;
    _finished = false;
    _status = _instructions;
    _answerController.clear();
  }

  String _randomCard() {
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['♠', '♥', '♦', '♣'];
    return '${ranks[_random.nextInt(ranks.length)]}${suits[_random.nextInt(suits.length)]}';
  }

  List<String> _makeOptions() {
    switch (_id) {
      case 'quick_math': return ['12', '18', '24', '30'];
      case 'sudoku': return ['1', '2', '3', '4'];
      case 'guess_song': case 'guess_artist': case 'guess_album': return ['Choose from library', 'Search library', 'Play preview', 'Skip'];
      case 'movie_trivia': case 'tv_trivia': return ['A', 'B', 'C', 'D'];
      case 'emoji_movie': case 'emoji_song': case 'tv_show_emoji': return ['Comedy', 'Adventure', 'Drama', 'Animation'];
      default: return ['Option A', 'Option B', 'Option C', 'Option D'];
    }
  }

  String get _instructions {
    switch (_id) {
      case 'reversi': return 'Place a disc to bracket opponent discs in a straight line and flip them. Most discs wins.';
      case 'gomoku': return 'Place stones on intersections. Connect five in a row horizontally, vertically, or diagonally.';
      case 'tic_tac_toe': return 'Take turns placing X and O. Connect three in a row to win.';
      case 'mancala': return 'Select one of your pits to sow stones counter-clockwise. Capture stones and finish with the largest store.';
      case 'chinese_checkers': return 'Select a peg, then a highlighted destination. Jump over pegs to race all pieces to the opposite star point.';
      case 'hearts': return 'Play one card per trick and follow suit when possible. Avoid hearts and the queen of spades.';
      case 'spades': return 'Bid how many tricks your partnership expects to win, then follow suit. Spades are trump.';
      case 'crazy_eights': return 'Play a card matching the discard rank or suit. Eights change the active suit.';
      case 'go_fish': return 'Ask an opponent for a rank. If they have it, collect the cards; otherwise draw from the pond.';
      case 'war': return 'Reveal the top card. Higher rank wins the battle; ties trigger war.';
      case 'gin_rummy': case 'rummy': return 'Draw one card, form sets or same-suit runs, then discard one card.';
      case 'old_maid': return 'Make matching pairs and avoid being left with the unmatched Old Maid.';
      case 'pool': return 'Aim the cue, set shot power, and pocket your assigned balls before the opponent.';
      case 'bowling': return 'Choose your aim and release timing. Knock down pins and score across ten frames.';
      case 'darts': return 'Choose a scoring segment. Follow the selected mode target and finish with the required score.';
      case 'mini_golf': return 'Aim for the cup, choose shot power, and finish each hole in as few strokes as possible.';
      case 'air_hockey': return 'Move your striker to defend your goal and shoot the puck past the opponent.';
      case 'pinball': return 'Use the flippers to keep the ball in play and hit bumpers for points.';
      case 'endless_runner': return 'Jump, slide, or switch lanes to avoid obstacles and collect items for distance.';
      case 'maze_chase': return 'Move through the maze, collect dots, and avoid pursuers.';
      case 'brick_breaker': return 'Move the paddle to bounce the ball and clear every brick.';
      case 'memory_match': return 'Select two tiles to reveal them. Find all matching pairs with the fewest moves.';
      case 'simon_says': return 'Watch the cue sequence, then repeat it in the same order.';
      case 'pattern_memory': return 'Study the pattern, then reproduce it before the timer runs out.';
      case 'quick_math': return 'Solve the arithmetic prompt. Correct answers earn points; continue through the rounds.';
      case 'number_guess': return 'Submit a guess and use higher/lower clues to find the hidden number.';
      case 'twenty_questions': return 'Ask yes/no questions to narrow down the secret answer.';
      case 'hangman': return 'Choose letters to reveal the hidden word before the attempts run out.';
      case 'word_scramble': return 'Rearrange the letters to spell the target word.';
      case 'word_ladder': return 'Change one letter at a time to transform the start word into the target word.';
      case 'anagrams': return 'Build valid words from the available letters to score points.';
      case 'word_search': return 'Find the listed words horizontally, vertically, or diagonally in the letter grid.';
      case 'guess_song': case 'guess_artist': case 'guess_album': case 'guess_genre': case 'guess_decade': case 'guess_year': case 'guess_music_video': case 'guess_instrument': case 'guess_cover_artist': case 'guess_original': case 'one_second_song': case 'three_second_song': case 'five_second_song': case 'ten_second_song': case 'first_note': case 'first_beat': case 'first_word': case 'fastest_guess': case 'finish_lyrics': case 'missing_lyrics': case 'next_word': case 'next_line': case 'lyrics_scramble': case 'who_sang_line': case 'lyrics_multiple_choice': case 'wrong_lyrics': case 'continue_song': case 'music_timeline': case 'which_song_first': case 'higher_lower_year': case 'higher_lower_streams': case 'artist_vs_artist': case 'album_vs_album': case 'guess_sample': case 'name_that_cover': case 'one_hit_wonder': case 'music_connections': case 'song_battle': case 'best_intro': case 'best_chorus': case 'best_bassline': case 'best_guitar': case 'best_party_song': case 'best_workout_song': case 'best_movie_song': case 'best_song_decade': return 'Music-library game surface. Choose a prompt or answer; track playback and metadata must come from your server media library.';
      case 'guess_movie': case 'guess_tv_show': case 'guess_actor': case 'guess_actress': case 'guess_character': case 'guess_director': case 'guess_franchise': case 'guess_episode': case 'guess_scene': case 'guess_location': case 'movie_soundtrack_guess': case 'tv_theme_guess': case 'movie_quote': case 'tv_quote': case 'who_said_it': case 'movie_sound_effect': case 'show_sound_effect': case 'blurred_scene': case 'zoomed_scene': case 'pixelated_movie': case 'silhouette_character': case 'actor_face': case 'movie_poster_puzzle': case 'missing_poster': case 'movie_trivia': case 'tv_trivia': case 'release_year': case 'actor_connections': case 'director_connections': case 'movie_timeline': case 'sequel_or_original': case 'remake_or_original': case 'movie_or_tv': case 'which_movie_first': case 'box_office_higher_lower': case 'runtime_higher_lower': case 'tv_show_emoji': return 'Media quiz board. Select an answer or enter a guess; media-specific prompts should be sourced from your library and licensed metadata.';
      case 'family_feud': case 'survey_says': return 'Teams reveal survey answers to score points. Use the host controls to reveal answers and track strikes.';
      case 'most_likely_to': case 'whos_most_likely': case 'would_you_rather': case 'never_have_i_ever': case 'two_truths_lie': case 'truth_or_bluff': case 'guess_who': case 'hot_seat': case 'act_it_out': case 'sound_effects': case 'impression_challenge': return 'Party round: choose a prompt, submit or vote, then reveal the room results.';
      case 'dance_challenge': case 'lip_sync_battle': case 'karaoke_battle': case 'music_racing': case 'beat_saber_style': case 'dance_coach': case 'rhythm_challenge': case 'dance_battle': case 'motion_sports': return 'Performance arena: select a track or mode, follow timed cues, and score accuracy. Motion tracking and media playback need device/server integration.';
      case 'cross_game_tournament': return 'Create a multi-game bracket, track each match result, and award tournament points separately from individual game scores.';
      case 'crossover_arena_fighter': return 'Arena prototype: choose a fighter, stage, and action. Franchise characters and artwork require appropriate distribution rights.';
      default: return widget.game.description;
    }
  }

  void _finishIfNeeded() {
    if (_finished) return;
    if (_score >= 10) {
      _finished = true;
      widget.onFinished('win');
    }
  }

  void _tapCell(int index) {
    if (_finished) return;
    setState(() {
      _moves++;
      _selected = index;
      if (_id == 'tic_tac_toe') {
        if (_cells[index] == 0) {
          _cells[index] = _turn.isEven ? 2 : 1;
          _turn++;
          if (_cells.where((v) => v != 0).length >= 9) {
            _status = 'Board full — start a new round.';
          }
          else {
            _status = 'Move placed. Player ${_turn.isEven ? '2 (O)' : '1 (X)'} to move.';
          }
        }
      } else if (_id == 'reversi' || _id == 'gomoku') {
        if (_cells[index] == 0) {
          _cells[index] = _turn.isEven ? 2 : 1;
          _turn++;
          _score += 1;
          _status = _id == 'gomoku' ? 'Stone placed. Build a line of five.' : 'Disc placed. Outflank opponent discs to flip them.';
        }
      } else if (_id == 'memory_match') {
        _cells[index] = _cells[index] == 0 ? 1 : 0;
        _status = 'Tile ${index + 1} selected. Find its matching pair.';
      } else {
        _cells[index] = _cells[index] == 0 ? 1 : 0;
        _score++;
        _status = 'Action registered. $_instructions';
      }
    });
    _finishIfNeeded();
  }

  void _playCard(int index) {
    if (_finished || index < 0 || index >= _hand.length) return;
    setState(() {
      final card = _hand.removeAt(index);
      _moves++;
      _score++;
      _status = 'Played $card. ${_hand.isEmpty ? 'Hand cleared!' : 'Choose your next card.'}';
      if (_hand.isEmpty) {
        _finished = true;
        widget.onFinished('win');
      }
    });
  }

  void _chooseOption(String option) {
    if (_finished) return;
    setState(() {
      _moves++;
      _score++;
      _status = 'Selected: $option. Round $_round recorded.';
      _round++;
      if (_round > 5) {
        _finished = true;
        widget.onFinished('win');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(widget.game.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              Chip(label: Text('Round $_round')),
            ]),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Chip(avatar: const Icon(Icons.stars, size: 16), label: Text('Score $_score')),
              Chip(avatar: const Icon(Icons.touch_app, size: 16), label: Text('Moves $_moves')),
              Chip(label: Text(widget.mode.toUpperCase())),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 14),
            if (_isBoard) _buildBoardSurface(),
            if (_isCard) _buildCardSurface(),
            if (_isGridPuzzle) _buildPuzzleSurface(),
            if (_isWord) _buildQuizSurface(),
            if (_isArcade) _buildArcadeSurface(),
            if (_isParty) _buildPartySurface(),
            if (!_isBoard && !_isCard && !_isGridPuzzle && !_isWord && !_isArcade && !_isParty) _buildGenericSurface(),
            const SizedBox(height: 12),
            Text(_instructions, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => setState(_reset), icon: const Icon(Icons.refresh), label: const Text('Restart'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: () => _chooseOption('Pass / confirm'), icon: const Icon(Icons.check_circle_outline), label: const Text('Confirm move'))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSurface() {
    if (_id == 'mancala') {
      return Column(children: [
        Row(children: [Expanded(child: _pit('OPPONENT STORE', 0, true)), const SizedBox(width: 8), ...List.generate(6, (i) => Expanded(child: _pit('${6-i}', i, false)))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _pit('YOUR STORE', 12, true)), const SizedBox(width: 8), ...List.generate(6, (i) => Expanded(child: _pit('${i+1}', i+6, false)))]),
      ]);
    }
    if (_id == 'chinese_checkers') {
      return AspectRatio(aspectRatio: 1, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 121, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 11, crossAxisSpacing: 2, mainAxisSpacing: 2), itemBuilder: (_, i) {
        final r = i ~/ 11; final c = i % 11; final valid = (r >= 3 && r <= 7) || (c >= 3 && c <= 7);
        return InkWell(onTap: valid ? () => _tapCell(i % _cells.length) : null, child: Center(child: valid ? Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: _cells[i % _cells.length] == 0 ? const Color(0xFF315B53) : Colors.amber, border: Border.all(color: Colors.white24))) : const SizedBox.shrink()));
      }));
    }
    final count = _id == 'tic_tac_toe' ? 3 : _id == 'gomoku' || _id == 'reversi' ? 8 : 5;
    return AspectRatio(aspectRatio: 1, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: count * count, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, crossAxisSpacing: 3, mainAxisSpacing: 3), itemBuilder: (_, i) {
      final value = _cells[i];
      final mark = _id == 'tic_tac_toe' ? (value == 1 ? 'X' : value == 2 ? 'O' : '') : _id == 'reversi' ? (value == 1 ? '●' : value == 2 ? '○' : '') : _id == 'gomoku' ? (value == 1 ? '●' : value == 2 ? '○' : '') : value == 0 ? '' : '●';
      return InkWell(onTap: () => _tapCell(i), child: Container(decoration: BoxDecoration(color: _id == 'reversi' || _id == 'gomoku' ? const Color(0xFF28745C) : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)), child: Center(child: Text(mark, style: TextStyle(fontSize: count == 8 ? 21 : 28, fontWeight: FontWeight.w900, color: value == 2 ? Colors.white : Theme.of(context).colorScheme.primary)))));
    }));
  }

  Widget _pit(String label, int index, bool store) => InkWell(onTap: () => _tapCell(index % _cells.length), child: Container(margin: const EdgeInsets.all(2), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2), decoration: BoxDecoration(color: store ? const Color(0xFF8C6842) : const Color(0xFFB88B58), borderRadius: BorderRadius.circular(store ? 24 : 12)), child: Column(children: [Text(store ? '●●●' : '${(_cells[index % _cells.length] % 5) + 3}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9))])));

  Widget _buildCardSurface() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF15533F), borderRadius: BorderRadius.circular(14)), child: Row(children: [Expanded(child: _pile('DRAW PILE', '▧', () => setState(() { _hand.add(_randomCard()); _status = 'Drew a card from the stock.'; _moves++; }))), const SizedBox(width: 12), Expanded(child: _pile('DISCARD', _hand.isEmpty ? '—' : _hand.last, () => _chooseOption('Take discard')))])),
    const SizedBox(height: 12),
    Text('YOUR HAND (${_hand.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    Wrap(spacing: 6, runSpacing: 8, children: List<Widget>.generate(_hand.length, (i) => InkWell(onTap: () => _playCard(i), child: Container(width: 48, height: 68, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _selected == i ? Colors.amber : Colors.black12, width: 2)), child: Center(child: Text(_hand[i], style: TextStyle(fontWeight: FontWeight.w900, color: _hand[i].contains('♥') || _hand[i].contains('♦') ? Colors.red : Colors.black))))))),
    if (_id == 'texas_holdem' || _id == 'blackjack' || _id == 'baccarat') Padding(padding: const EdgeInsets.only(top: 10), child: Text('Play-money table only • no real-money wagering', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700))),
  ]);

  Widget _pile(String title, String card, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Container(height: 76, width: 58, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white70, width: 2)), child: Center(child: Text(card, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))), const SizedBox(height: 5), Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]));

  Widget _buildPuzzleSurface() => Column(children: [
    if (_id == 'sudoku') const Text('DAILY NUMBER GRID', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
    AspectRatio(aspectRatio: 1, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 81, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9, crossAxisSpacing: 1, mainAxisSpacing: 1), itemBuilder: (_, i) => InkWell(onTap: () => _tapCell(i % _cells.length), child: Container(decoration: BoxDecoration(color: _cells[i % _cells.length] == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.primaryContainer, border: Border.all(color: Colors.white10)), child: Center(child: Text(_cells[i % _cells.length] == 0 ? (i % 9 + 1).toString() : '', style: const TextStyle(fontSize: 10))))))),
    if (_id == 'minesweeper') Wrap(spacing: 6, children: [for (final a in ['Reveal', 'Flag', 'Hint']) OutlinedButton(onPressed: () => _chooseOption(a), child: Text(a))]),
  ]);

  Widget _buildQuizSurface() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF252D4B), Color(0xFF533A69)]), borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(_category == 'music' ? Icons.music_note : _category == 'movieTv' ? Icons.local_movies : Icons.quiz, size: 36, color: Colors.white), const SizedBox(height: 8), Text(_id.replaceAll('_', ' ').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(height: 6), Text(_prompt, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))])),
    const SizedBox(height: 10),
    if (_id == 'hangman') Text('WORD: ${List.filled(6, '＿').join(' ')}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, letterSpacing: 3)),
    if (_id == 'word_scramble') const Text('R E A P L Y', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 5)),
    if (_id == 'word_search') _buildLetterGrid(),
    if (_id == 'word_scramble' || _id == 'word_ladder' || _id == 'anagrams' || _id == 'hangman' || _id == 'spell_it' || _id == 'password' || _id == 'word_chain' || _id == 'word_association' || _id == 'categories') Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: TextField(controller: _answerController, decoration: const InputDecoration(labelText: 'Your answer', border: OutlineInputBorder()), onSubmitted: (v) => _chooseOption(v))),
    for (final option in _options) Padding(padding: const EdgeInsets.only(bottom: 7), child: OutlinedButton(onPressed: () => _chooseOption(option), child: Text(option))),
    if (_category == 'music' || _category == 'movieTv') OutlinedButton.icon(onPressed: () => _chooseOption('Skip / next clue'), icon: const Icon(Icons.skip_next), label: const Text('Skip / next clue')),
  ]);

  String get _prompt {
    switch (_id) {
      case 'quick_math': return 'What is 6 × 4?';
      case 'number_guess': return 'Guess the hidden number from 1 to 100.';
      case 'word_scramble': return 'Unscramble the letters above.';
      case 'hangman': return 'Guess a letter in the hidden word.';
      case 'guess_song': return 'Which track is playing? Select a server-library track to begin.';
      case 'guess_movie': return 'Identify the title from your media-library clues.';
      case 'finish_lyrics': case 'missing_lyrics': case 'next_line': return 'Complete the prompt using licensed or user-provided lyric text.';
      default: return 'Prompt $_round: choose the best answer or enter your response.';
    }
  }

  Widget _buildLetterGrid() => Padding(padding: const EdgeInsets.only(bottom: 12), child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 8, childAspectRatio: 1.1, children: List.generate(40, (i) => Center(child: Text(String.fromCharCode(65 + ((i * 7 + 3) % 26)), style: const TextStyle(fontWeight: FontWeight.w900))))));

  Widget _buildArcadeSurface() => Column(children: [
    Container(height: 190, decoration: BoxDecoration(color: const Color(0xFF10182B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)), child: Stack(alignment: Alignment.center, children: [
      if (_id == 'pool') CustomPaint(size: Size.infinite, painter: _PoolTablePainter()),
      if (_id == 'bowling') const Icon(Icons.sports, size: 72, color: Colors.white70),
      if (_id == 'darts') const Icon(Icons.gps_fixed, size: 90, color: Colors.redAccent),
      if (_id == 'mini_golf') const Icon(Icons.golf_course, size: 90, color: Colors.lightGreenAccent),
      if (_id == 'air_hockey') const Icon(Icons.sports_hockey, size: 90, color: Colors.lightBlueAccent),
      if (_id == 'pinball' || _id == 'brick_breaker') const Icon(Icons.videogame_asset, size: 90, color: Colors.amber),
      if (_id == 'music_racing' || _id == 'endless_runner') const Icon(Icons.speed, size: 90, color: Colors.orangeAccent),
      if (_id == 'beat_saber_style' || _id == 'dance_coach' || _id == 'rhythm_challenge' || _id == 'dance_battle' || _id == 'karaoke_battle' || _id == 'lip_sync_battle' || _id == 'dance_challenge') const Icon(Icons.graphic_eq, size: 90, color: Colors.pinkAccent),
      if (_id == 'crossover_arena_fighter') const Icon(Icons.sports_mma, size: 90, color: Colors.redAccent),
      Positioned(bottom: 8, child: Text('SCORE  $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2))),
    ])),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: FilledButton(onPressed: () => _chooseOption('Action / hit'), child: const Text('ACTION'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _chooseOption('Move / aim'), child: const Text('MOVE / AIM'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _chooseOption('Special'), child: const Text('SPECIAL')))]),
  ]);

  Widget _buildPartySurface() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF382A62), borderRadius: BorderRadius.circular(14)), child: Column(children: [const Icon(Icons.groups, color: Colors.white, size: 44), const SizedBox(height: 8), Text('ROUND $_round', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), Text(_id == 'would_you_rather' ? 'Choose A or B' : _id == 'family_feud' || _id == 'survey_says' ? 'Reveal the top survey answer' : 'Submit your choice, then reveal votes', style: const TextStyle(color: Colors.white70))])),
    const SizedBox(height: 10),
    for (final option in _options) Padding(padding: const EdgeInsets.only(bottom: 7), child: FilledButton.tonal(onPressed: () => _chooseOption(option), child: Text(option))),
    TextField(controller: _answerController, decoration: const InputDecoration(labelText: 'Your response (optional)', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () => _chooseOption('Reveal results'), icon: const Icon(Icons.visibility), label: const Text('Reveal results')),
  ]);

  Widget _buildGenericSurface() => Column(children: [Icon(Icons.sports_esports, size: 72, color: Theme.of(context).colorScheme.primary), Text(widget.game.name, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 10), for (final option in _options) OutlinedButton(onPressed: () => _chooseOption(option), child: Text(option))]);
}

class _PoolTablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final felt = Paint()..color = const Color(0xFF176448);
    final rail = Paint()..color = const Color(0xFF81552F);
    final ball = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), rail);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(12, 12, size.width - 24, size.height - 24), const Radius.circular(8)), felt);
    for (final p in [const Offset(.08,.12), const Offset(.5,.12), const Offset(.92,.12), const Offset(.08,.88), const Offset(.5,.88), const Offset(.92,.88)]) {
      canvas.drawCircle(Offset(size.width*p.dx, size.height*p.dy), 6, Paint()..color = Colors.black);
    }
    for (var i=0;i<7;i++) { canvas.drawCircle(Offset(size.width*.45 + (i%3)*10, size.height*.45 + (i~/3)*10), 5, ball..color = [Colors.yellow, Colors.red, Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.white][i]); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    const mediaGameCategories = <GameCategory>{
      GameCategory.music,
      GameCategory.movieTv,
      GameCategory.danceRhythm,
    };
    final daily = GameCatalog.definitions
        .where((game) => game.supportsDaily && mediaGameCategories.contains(game.category))
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
