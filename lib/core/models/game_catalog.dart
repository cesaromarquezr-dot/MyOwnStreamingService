enum GameCategory {
  board,
  card,
  casinoPlayMoney,
  puzzle,
  arcade,
  dominoes,
  tile,
  word,
}

enum GameMode {
  solo,
  ai,
  friend,
  casual,
  ranked,
  tournament,
  daily,
  local,
}

class GameDefinition {
  final String id;
  final String name;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final bool supportsAi;
  final bool supportsRanked;
  final bool supportsDaily;
  final bool playMoneyOnly;
  final String description;
  final List<String> aliases;

  const GameDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.minPlayers,
    required this.maxPlayers,
    this.supportsAi = false,
    this.supportsRanked = false,
    this.supportsDaily = false,
    this.playMoneyOnly = false,
    this.description = '',
    this.aliases = const [],
  });
}

class GameRating {
  final String gameId;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  const GameRating({
    required this.gameId,
    required this.rating,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  double get winRate => gamesPlayed <= 0 ? 0 : wins / gamesPlayed;

  factory GameRating.fromJson(Map<String, dynamic> json) => GameRating(
        gameId: json['gameId']?.toString() ?? json['game_id']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toInt() ??
            int.tryParse(json['rating']?.toString() ?? '') ?? 500,
        gamesPlayed: (json['gamesPlayed'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
      );
}

class GameCatalog {
  GameCatalog._();
  static final GameCatalog instance = GameCatalog._();

  static const definitions = <GameDefinition>[
    GameDefinition(id: 'chess', name: 'Chess', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true, description: 'Classic chess with casual, ranked, friend and AI play.'),
    GameDefinition(id: 'checkers', name: 'Checkers', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'connect4', name: 'Connect 4', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'ludo', name: 'Ludo', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'snakes_ladders', name: 'Snakes & Ladders', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsAi: true),
    GameDefinition(id: 'backgammon', name: 'Backgammon', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'battleship', name: 'Battleship', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true),
    GameDefinition(id: 'solitaire', name: 'Solitaire', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'tripeaks', name: 'TriPeaks', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'pyramid', name: 'Pyramid', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'freecell', name: 'FreeCell', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'spider', name: 'Spider', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'continental', name: 'Continental', category: GameCategory.card, minPlayers: 2, maxPlayers: 6, supportsAi: true),
    GameDefinition(id: 'la_viuda', name: 'La Viuda', category: GameCategory.card, minPlayers: 2, maxPlayers: 6, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'uno_like', name: 'UNO', category: GameCategory.card, minPlayers: 2, maxPlayers: 10, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'texas_holdem', name: 'Texas Hold\'em', category: GameCategory.casinoPlayMoney, minPlayers: 2, maxPlayers: 9, supportsAi: true, playMoneyOnly: true),
    GameDefinition(id: 'blackjack', name: 'Blackjack (21)', category: GameCategory.casinoPlayMoney, minPlayers: 1, maxPlayers: 7, supportsAi: true, playMoneyOnly: true),
    GameDefinition(id: 'baccarat', name: 'Baccarat', category: GameCategory.casinoPlayMoney, minPlayers: 1, maxPlayers: 8, supportsAi: true, playMoneyOnly: true),
    GameDefinition(id: 'sudoku', name: 'Sudoku', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'mahjong', name: 'Mahjong', category: GameCategory.tile, minPlayers: 1, maxPlayers: 4, supportsAi: true, supportsDaily: true),
    GameDefinition(id: 'jigsaw', name: 'Jigsaw', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'word_search', name: 'Word Search', category: GameCategory.word, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'minesweeper', name: 'Minesweeper', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'snake', name: 'Snake', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'bubble', name: 'Bubble Shooter', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'bejeweled_like', name: 'Gem Match', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'gravity_block', name: 'Gravity Block', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'gem_drop', name: 'Gem Drop', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1),
    GameDefinition(id: 'queens', name: 'Queens', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'tango', name: 'Tango', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'patches', name: 'Patches', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'zip', name: 'Zip', category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'wend', name: 'Wend', category: GameCategory.word, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'pinpoint', name: 'Pinpoint', category: GameCategory.word, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'crossclimb', name: 'Crossclimb', category: GameCategory.word, minPlayers: 1, maxPlayers: 1, supportsDaily: true),
    GameDefinition(id: 'dominoes', name: 'Classic Dominoes', category: GameCategory.dominoes, minPlayers: 2, maxPlayers: 4, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'draw_dominoes', name: 'Draw Dominoes', category: GameCategory.dominoes, minPlayers: 2, maxPlayers: 4, supportsAi: true),
    GameDefinition(id: 'all_fives', name: 'All Fives', category: GameCategory.dominoes, minPlayers: 2, maxPlayers: 4, supportsAi: true),
    GameDefinition(id: 'chicken_foot', name: 'Chicken Foot', category: GameCategory.dominoes, minPlayers: 2, maxPlayers: 8, supportsAi: true),
    GameDefinition(id: 'mexican_train', name: 'Mexican Train', category: GameCategory.dominoes, minPlayers: 2, maxPlayers: 8, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'rummikub', name: 'Rummikub-style', category: GameCategory.tile, minPlayers: 2, maxPlayers: 4, supportsAi: true, supportsRanked: true),
  ];

  List<GameDefinition> byCategory(GameCategory category) =>
      definitions.where((game) => game.category == category).toList(growable: false);

  GameDefinition byId(String id) => definitions.firstWhere(
        (game) => game.id == id,
        orElse: () => definitions.first,
      );
}
