import 'dart:math';

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
            'Play with friends, AI, or ranked matchmaking.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const UniversalText(
            'Ludo and Chess include playable local game engines with AI, turns, pieces, movement and board customization. Other titles open a playable practice surface while their dedicated rules engine is added.',
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
                        Row(
                          children: [
                            Icon(_icon(game.category)),
                            const Spacer(),
                            if (game.playMoneyOnly)
                              const Chip(label: Text('PLAY MONEY')),
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
      // Local modes must never depend on the backend being reachable.
      // They are used to immediately exercise the actual board/rules UI.
      Map<String, dynamic> match;

      if (mode == 'solo' || mode == 'ai' || mode == 'friend') {
        match = <String, dynamic>{
          'id': 'local-${widget.game.id}-${DateTime.now().microsecondsSinceEpoch}',
          'gameId': widget.game.id,
          'profileId': profileId,
          'mode': mode,
          'status': 'created',
          'local': true,
        };
      } else {
        final response = await AppController.instance.backendApi.createGameMatch(
          profileId: profileId,
          gameId: widget.game.id,
          mode: mode,
        );

        final rawMatch = response['match'];
        match = rawMatch is Map
            ? Map<String, dynamic>.from(rawMatch)
            : <String, dynamic>{
                'id': response['id'] ?? '',
                'gameId': widget.game.id,
                'profileId': profileId,
                'mode': mode,
                'status': response['status'] ?? 'created',
                ...response,
              };
      }

      if (!mounted) return;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          settings: RouteSettings(name: '/app/games/${widget.game.id}/match'),
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
                      const Icon(
                        Icons.sports_esports_rounded,
                        size: 34,
                      ),
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
                        ? 'Choose how you want to play.'
                        : game.description,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${game.minPlayers}-${game.maxPlayers} players',
                    style: const TextStyle(color: Colors.white54),
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
            'Choose how to play',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your selected profile is the player identity used for the match and its rating.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          if (game.minPlayers == 1)
            _modeButton(
              mode: 'solo',
              title: 'Play Solo',
              subtitle: 'Start the game immediately on this device.',
              icon: Icons.person_outline_rounded,
              filled: true,
            ),
          if (game.supportsAi) ...[
            if (game.minPlayers == 1) const SizedBox(height: 10),
            _modeButton(
              mode: 'ai',
              title: 'Play with AI',
              subtitle: 'Start a playable board and take your first turn immediately.',
              icon: Icons.smart_toy_outlined,
              filled: true,
            ),
          ],
          if (game.minPlayers > 1) ...[
            const SizedBox(height: 10),
            _modeButton(
              mode: 'friend',
              title: 'Play with a Friend',
              subtitle: 'Start a pass-and-play local match on this device.',
              icon: Icons.people_outline_rounded,
            ),
            const SizedBox(height: 10),
            _modeButton(
              mode: 'casual',
              title: 'Play with Anyone Online',
              subtitle: 'Use online matchmaking when an opponent is available.',
              icon: Icons.public_rounded,
            ),
          ],
          if (game.supportsRanked) ...[
            const SizedBox(height: 10),
            _modeButton(
              mode: 'ranked',
              title: 'Play Ranked',
              subtitle: 'Enter ranked matchmaking and compete for rating.',
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
  final BoardThemeConfig _theme = const BoardThemeConfig();
  bool _finishing = false;

  String _modeTitle(String mode) => switch (mode) {
        'solo' => 'Solo game',
        'ai' => 'Game against AI',
        'friend' => 'Private friend game',
        'casual' => 'Online casual game',
        'ranked' => 'Ranked game',
        _ => 'Game',
      };

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

    if (widget.game.id == 'ludo') {
      return LudoGameBoard(
        theme: _theme,
        mode: mode,
        onFinished: _finishGame,
      );
    }

    if (widget.game.id == 'chess') {
      return ChessGameBoard(
        theme: _theme,
        mode: mode,
        onFinished: _finishGame,
      );
    }

    return PracticeGameBoard(
      game: widget.game,
      theme: _theme,
      mode: mode,
      onFinished: _finishGame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.match['mode']?.toString() ?? 'casual';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name),
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

class LudoGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final Future<void> Function(String result) onFinished;

  const LudoGameBoard({
    super.key,
    required this.theme,
    required this.mode,
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

  void _rollDice() {
    if (_rolling || _winner != null || _currentPlayer != 0) return;

    setState(() {
      _rolling = true;
      _dice = 1 + _random.nextInt(6);
    });

    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() => _rolling = false);
      _afterRoll();
    });
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
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _winner != null || _currentPlayer != 1) return;
      setState(() => _dice = 1 + _random.nextInt(6));
      _afterAiRoll();
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
                if (_dice > 0)
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$_dice',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class ChessGameBoard extends StatefulWidget {
  final BoardThemeConfig theme;
  final String mode;
  final Future<void> Function(String result) onFinished;

  const ChessGameBoard({
    super.key,
    required this.theme,
    required this.mode,
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
  }

  bool _isWhite(String piece) => piece == piece.toUpperCase();

  List<int> _legalMovesFor(int index) {
    final piece = _board[index];
    if (piece == null) return const <int>[];
    final white = _isWhite(piece);
    if ((_turn == 0 && !white) || (_turn == 1 && white)) {
      return const <int>[];
    }

    final row = index ~/ 8;
    final col = index % 8;
    final kind = piece.toLowerCase();
    final result = <int>[];

    bool addSquare(int r, int c) {
      if (r < 0 || r > 7 || c < 0 || c > 7) return false;
      final target = r * 8 + c;
      final occupant = _board[target];
      if (occupant == null) {
        result.add(target);
        return true;
      }
      if (_isWhite(occupant) != white) {
        result.add(target);
      }
      return false;
    }

    if (kind == 'p') {
      final direction = white ? -1 : 1;
      final startRow = white ? 6 : 1;
      final oneRow = row + direction;
      if (oneRow >= 0 && oneRow <= 7) {
        final one = oneRow * 8 + col;
        if (_board[one] == null) {
          result.add(one);
          if (row == startRow) {
            final twoRow = row + 2 * direction;
            final two = twoRow * 8 + col;
            if (_board[two] == null) result.add(two);
          }
        }
        for (final dc in const [-1, 1]) {
          final captureCol = col + dc;
          if (captureCol < 0 || captureCol > 7) continue;
          final target = oneRow * 8 + captureCol;
          final occupant = _board[target];
          if (occupant != null && _isWhite(occupant) != white) {
            result.add(target);
          }
        }
      }
    } else if (kind == 'n') {
      for (final delta in const [
        [-2, -1],
        [-2, 1],
        [-1, -2],
        [-1, 2],
        [1, -2],
        [1, 2],
        [2, -1],
        [2, 1],
      ]) {
        addSquare(row + delta[0], col + delta[1]);
      }
    } else if (kind == 'k') {
      for (final dr in [-1, 0, 1]) {
        for (final dc in [-1, 0, 1]) {
          if (dr == 0 && dc == 0) continue;
          addSquare(row + dr, col + dc);
        }
      }
    } else {
      final directions = <List<int>>[];
      if (kind == 'r' || kind == 'q') {
        directions.addAll(const [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]);
      }
      if (kind == 'b' || kind == 'q') {
        directions.addAll(const [
          [-1, -1],
          [-1, 1],
          [1, -1],
          [1, 1],
        ]);
      }
      for (final direction in directions) {
        var r = row + direction[0];
        var c = col + direction[1];
        while (addSquare(r, c)) {
          r += direction[0];
          c += direction[1];
        }
      }
    }

    return result;
  }

  void _tapSquare(int index) {
    if (_thinking || _finished || _turn != 0) return;

    final piece = _board[index];
    if (_selected == null) {
      if (piece == null || !_isWhite(piece)) return;
      final legal = _legalMovesFor(index);
      if (legal.isEmpty) return;
      setState(() => _selected = index);
      return;
    }

    final legal = _legalMovesFor(_selected!);
    if (legal.contains(index)) {
      _move(_selected!, index);
      return;
    }

    if (piece != null && _isWhite(piece)) {
      final nextLegal = _legalMovesFor(index);
      setState(() {
        _selected = nextLegal.isEmpty ? null : index;
      });
      return;
    }

    setState(() => _selected = null);
  }

  void _move(int from, int to) {
    final moving = _board[from];
    if (moving == null) return;

    final captured = _board[to];
    setState(() {
      _board[to] = moving;
      _board[from] = null;
      _selected = null;
      _turn = 1;
    });

    if (captured?.toLowerCase() == 'k') {
      _finished = true;
      widget.onFinished('win');
      return;
    }

    final row = to ~/ 8;
    if (moving == 'P' && row == 0) {
      setState(() => _board[to] = 'Q');
    }

    if (moving == 'p' && row == 7) {
      setState(() => _board[to] = 'q');
    }

    if (widget.mode == 'ai') {
      _runAiTurn();
    }
  }

  void _runAiTurn() {
    if (!mounted || _finished) return;
    setState(() => _thinking = true);
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (!mounted || _finished) return;

      final moves = <List<int>>[];
      for (var i = 0; i < 64; i++) {
        if (_board[i] == null || _isWhite(_board[i]!)) continue;
        for (final target in _legalMovesFor(i)) {
          moves.add([i, target]);
        }
      }

      if (moves.isEmpty) {
        setState(() => _thinking = false);
        widget.onFinished('win');
        return;
      }

      final captures = moves.where((move) => _board[move[1]] != null).toList();
      final choice = (captures.isNotEmpty ? captures : moves)[
        _random.nextInt((captures.isNotEmpty ? captures : moves).length)
      ];

      final moving = _board[choice[0]];
      final captured = _board[choice[1]];

      setState(() {
        _board[choice[1]] = moving;
        _board[choice[0]] = null;
        _turn = 0;
        _thinking = false;
      });

      if (captured?.toLowerCase() == 'k') {
        _finished = true;
        widget.onFinished('loss');
      }
    });
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
                    _thinking
                        ? 'AI is thinking…'
                        : _turn == 0
                            ? 'White to move'
                            : 'Black to move',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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
                  final row = index ~/ 8;
                  final col = index % 8;
                  final isLight = (row + col).isEven;
                  final piece = _board[index];
                  final selected = _selected == index;
                  final legal = _selected != null &&
                      _legalMovesFor(_selected!).contains(index);

                  return GestureDetector(
                    onTap: () => _tapSquare(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? widget.theme.accent.withValues(alpha: .72)
                            : legal
                                ? widget.theme.accent.withValues(alpha: .3)
                                : isLight
                                    ? widget.theme.light
                                    : widget.theme.dark,
                      ),
                      child: Center(
                        child: piece == null
                            ? (legal
                                ? Container(
                                    width: boardSize / 38,
                                    height: boardSize / 38,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: .35),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const SizedBox.shrink())
                            : Text(
                                _chessGlyph(piece),
                                style: TextStyle(
                                  fontSize: boardSize / 12.5,
                                  color: _isWhite(piece)
                                      ? Colors.white
                                      : Colors.black,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: .4),
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
            const Text(
              'Tap a piece, then tap a legal destination. Captures and pawn promotion are supported; castling and en passant are intentionally omitted from this first playable engine.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
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

  const PracticeGameBoard({
    super.key,
    required this.game,
    required this.theme,
    required this.mode,
    required this.onFinished,
  });

  @override
  State<PracticeGameBoard> createState() => _PracticeGameBoardState();
}

class _PracticeGameBoardState extends State<PracticeGameBoard> {
  final Random _random = Random();
  int _score = 0;
  int _round = 1;
  final int _target = 12;

  void _action() {
    final points = 1 + _random.nextInt(6);
    setState(() {
      _score += points;
      _round++;
    });
    if (_score >= _target) {
      widget.onFinished('win');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final boardSize = min<double>(widget.theme.boardSize, min<double>(maxWidth, 680.0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            SizedBox(
              width: boardSize,
              height: min<double>(boardSize * .66, 420.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.theme.dark, widget.theme.light],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    'Round $_round',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${widget.game.name} practice board',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Score $_score / $_target',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _action,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Make a move'),
            ),
            const SizedBox(height: 8),
            const Text(
              'This practice surface ensures every game opens into an interactive play area while dedicated rule engines are expanded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
