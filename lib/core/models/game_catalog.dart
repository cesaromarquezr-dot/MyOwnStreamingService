enum GameCategory {
  board,
  card,
  casinoPlayMoney,
  puzzle,
  arcade,
  dominoes,
  tile,
  word,
  trivia,
  party,
  music,
  movieTv,
  racing,
  danceRhythm,
  fighting,
  tournament,
  sports,
}

enum GamePlatformScope {
  allScreens,
  consolePcOnly,
}


class GameVariantDefinition {
  final String id;
  final String name;
  final String description;

  const GameVariantDefinition({
    required this.id,
    required this.name,
    this.description = '',
  });
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
  final int diceCount;
  final bool usesCards;
  /// False means the game is in the platform roadmap/catalog but its playable
  /// engine is not yet implemented. The UI must not launch a fake match.
  final bool isPlayable;
  /// The crossover arena fighter is intentionally unavailable on phones/tablets.
  final GamePlatformScope platformScope;
  /// Uses the existing user's server media IDs instead of duplicating audio/video.
  final bool usesServerMedia;
  /// Supports the shared phone motion-controller infrastructure when implemented.
  final bool supportsPhoneMotionController;

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
    this.diceCount = 0,
    this.usesCards = false,
    this.isPlayable = true,
    this.platformScope = GamePlatformScope.allScreens,
    this.usesServerMedia = false,
    this.supportsPhoneMotionController = false,
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
    GameDefinition(
      id: 'chess',
      name: 'Chess',
      category: GameCategory.board,
      minPlayers: 2,
      maxPlayers: 2,
      supportsAi: true,
      supportsRanked: true,
      description: 'Full legal chess with check, checkmate, castling, en passant and promotion.',
    ),
    GameDefinition(id: 'checkers', name: 'Checkers', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'connect4', name: 'Connect 4', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true),
    GameDefinition(id: 'ludo', name: 'Ludo', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsAi: true, supportsRanked: true, diceCount: 1),
    GameDefinition(id: 'snakes_ladders', name: 'Snakes & Ladders', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsAi: true, diceCount: 1),
    GameDefinition(id: 'monopoly', name: 'Monopoly', category: GameCategory.board, minPlayers: 2, maxPlayers: 8, supportsAi: true, diceCount: 2, aliases: ['Monopoly'], description: 'Property-trading board game using two dice, purchases, rent, taxes, cards and jail.'),
    GameDefinition(id: 'sorry', name: 'Sorry!', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsAi: true, usesCards: true, aliases: ['Sorry'], description: 'Card-driven pawn race with slides, bumping and home rules.'),
    GameDefinition(id: 'backgammon', name: 'Backgammon', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true, supportsRanked: true, diceCount: 2),
    GameDefinition(id: 'battleship', name: 'Battleship', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsAi: true),
    GameDefinition(id: 'solitaire', name: 'Solitaire', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true, usesCards: true),
    GameDefinition(id: 'tripeaks', name: 'TriPeaks', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true, usesCards: true),
    GameDefinition(id: 'pyramid', name: 'Pyramid', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true, usesCards: true),
    GameDefinition(id: 'freecell', name: 'FreeCell', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true, usesCards: true),
    GameDefinition(id: 'spider', name: 'Spider', category: GameCategory.card, minPlayers: 1, maxPlayers: 1, supportsDaily: true, usesCards: true),
    GameDefinition(id: 'continental', name: 'Continental', category: GameCategory.card, minPlayers: 2, maxPlayers: 6, supportsAi: true, usesCards: true),
    GameDefinition(id: 'la_viuda', name: 'La Viuda', category: GameCategory.card, minPlayers: 2, maxPlayers: 6, supportsAi: true, supportsRanked: true, usesCards: true),
    GameDefinition(id: 'uno_like', name: 'UNO', category: GameCategory.card, minPlayers: 2, maxPlayers: 10, supportsAi: true, supportsRanked: true, usesCards: true),
    GameDefinition(id: 'texas_holdem', name: 'Texas Hold\'em', category: GameCategory.casinoPlayMoney, minPlayers: 2, maxPlayers: 9, supportsAi: true, playMoneyOnly: true, usesCards: true),
    GameDefinition(id: 'blackjack', name: 'Blackjack (21)', category: GameCategory.casinoPlayMoney, minPlayers: 1, maxPlayers: 7, supportsAi: true, playMoneyOnly: true, usesCards: true),
    GameDefinition(id: 'baccarat', name: 'Baccarat', category: GameCategory.casinoPlayMoney, minPlayers: 1, maxPlayers: 8, supportsAi: true, playMoneyOnly: true, usesCards: true),
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

    GameDefinition(id: "reversi", name: "Reversi / Othello", category: GameCategory.board, minPlayers: 2, maxPlayers: 2, description: "Capture the opponent\u2019s discs by outflanking lines.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "gomoku", name: "Gomoku", category: GameCategory.board, minPlayers: 2, maxPlayers: 2, description: "Connect five stones in a row.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "tic_tac_toe", name: "Tic-Tac-Toe", category: GameCategory.board, minPlayers: 2, maxPlayers: 2, description: "Quick noughts-and-crosses matches.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "mancala", name: "Mancala", category: GameCategory.board, minPlayers: 2, maxPlayers: 2, description: "Distribute stones and capture more than your opponent.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "chinese_checkers", name: "Chinese Checkers", category: GameCategory.board, minPlayers: 2, maxPlayers: 6, description: "Race your pieces across the star-shaped board.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "hearts", name: "Hearts", category: GameCategory.card, minPlayers: 3, maxPlayers: 4, description: "Avoid penalty cards and the queen of spades.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "spades", name: "Spades", category: GameCategory.card, minPlayers: 4, maxPlayers: 4, description: "Bid tricks with a partner and meet your contract.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "crazy_eights", name: "Crazy Eights", category: GameCategory.card, minPlayers: 2, maxPlayers: 7, description: "Play matching suits or ranks and use action cards.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "go_fish", name: "Go Fish", category: GameCategory.card, minPlayers: 2, maxPlayers: 6, description: "Ask for ranks and collect sets.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "war", name: "War", category: GameCategory.card, minPlayers: 2, maxPlayers: 2, description: "Compare cards in a fast, luck-driven duel.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "gin_rummy", name: "Gin Rummy", category: GameCategory.card, minPlayers: 2, maxPlayers: 2, description: "Build sets and runs, knock, and minimize deadwood.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "rummy", name: "Rummy", category: GameCategory.card, minPlayers: 2, maxPlayers: 6, description: "Form sets and runs from a shared draw/discard pile.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "old_maid", name: "Old Maid", category: GameCategory.card, minPlayers: 2, maxPlayers: 6, description: "Make pairs and avoid holding the unmatched card.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "pool", name: "Pool", category: GameCategory.sports, minPlayers: 2, maxPlayers: 2, description: "Play cue-sport rules with aiming and shot power.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "bowling", name: "Bowling", category: GameCategory.sports, minPlayers: 1, maxPlayers: 6, description: "Aim, time the release, and score frames.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "darts", name: "Darts", category: GameCategory.sports, minPlayers: 1, maxPlayers: 4, description: "Aim at scoring segments and finish the selected game mode.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "mini_golf", name: "Mini Golf", category: GameCategory.sports, minPlayers: 1, maxPlayers: 4, description: "Navigate themed holes with stroke limits.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "air_hockey", name: "Air Hockey", category: GameCategory.arcade, minPlayers: 2, maxPlayers: 2, description: "Fast two-player puck battles.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "pinball", name: "Pinball", category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1, description: "Keep the ball alive and chase a high score.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "endless_runner", name: "Endless Runner", category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1, description: "Dodge hazards and collect items for distance.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "maze_chase", name: "Pac-Man-style Maze", category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1, description: "Navigate a maze, collect dots, and avoid pursuers.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "brick_breaker", name: "Brick Breaker", category: GameCategory.arcade, minPlayers: 1, maxPlayers: 1, description: "Bounce a ball to clear bricks and survive each level.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "reaction_race", name: "Reaction Race", category: GameCategory.party, minPlayers: 2, maxPlayers: 8, description: "Compete on reaction time and input accuracy.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "memory_match", name: "Memory Match", category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 4, description: "Find matching pairs with the fewest moves.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "simon_says", name: "Simon Says", category: GameCategory.party, minPlayers: 1, maxPlayers: 8, description: "Repeat an increasingly long sequence of cues.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "pattern_memory", name: "Pattern Memory", category: GameCategory.puzzle, minPlayers: 1, maxPlayers: 8, description: "Remember and reproduce patterns under a timer.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "quick_math", name: "Quick Math", category: GameCategory.trivia, minPlayers: 1, maxPlayers: 8, description: "Solve timed arithmetic rounds; fastest correct answers score most.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "number_guess", name: "Number Guess", category: GameCategory.party, minPlayers: 2, maxPlayers: 12, description: "Use clues to find the hidden number.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "twenty_questions", name: "20 Questions", category: GameCategory.party, minPlayers: 2, maxPlayers: 12, description: "Narrow a secret answer with yes/no questions.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "hangman", name: "Hangman", category: GameCategory.word, minPlayers: 1, maxPlayers: 4, description: "Reveal the word before guesses run out.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "word_scramble", name: "Word Scramble", category: GameCategory.word, minPlayers: 1, maxPlayers: 8, description: "Unscramble words before the round timer expires.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "word_ladder", name: "Word Ladder", category: GameCategory.word, minPlayers: 1, maxPlayers: 4, description: "Transform one word into another one letter at a time.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "anagrams", name: "Anagrams", category: GameCategory.word, minPlayers: 1, maxPlayers: 8, description: "Build valid words from a shared letter set.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "word_association", name: "Word Association", category: GameCategory.party, minPlayers: 2, maxPlayers: 12, description: "Connect ideas under time pressure.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "categories", name: "Categories", category: GameCategory.party, minPlayers: 2, maxPlayers: 12, description: "Name valid items in a category before time runs out.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "word_chain", name: "Word Chain", category: GameCategory.word, minPlayers: 2, maxPlayers: 12, description: "Each answer starts from the prior word\u2019s ending cue.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "spell_it", name: "Spell It", category: GameCategory.word, minPlayers: 1, maxPlayers: 8, description: "Spell words from audio or written clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "password", name: "Password", category: GameCategory.party, minPlayers: 2, maxPlayers: 12, description: "Give limited clues so a teammate can identify the secret word.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "taboo_style", name: "Taboo-style", category: GameCategory.party, minPlayers: 4, maxPlayers: 12, description: "Describe a word without using forbidden clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "charades", name: "Charades", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Act out a prompt without speaking.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "pictionary", name: "Pictionary", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Draw a prompt while teammates guess.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "draw_and_guess", name: "Draw & Guess", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Draw prompts and guess other players\u2019 drawings.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "emoji_pictionary", name: "Emoji Pictionary", category: GameCategory.party, minPlayers: 1, maxPlayers: 16, description: "Decode titles, phrases, and objects from emoji clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "emoji_movie", name: "Emoji Movie", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify movies from emoji clue sequences.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "emoji_song", name: "Emoji Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify songs from emoji clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "guess_song", name: "Guess the Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify tracks from short clips in the existing server music library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_artist", name: "Guess the Artist", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify the performer from a track or clue.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_album", name: "Guess the Album", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Match a track or artwork to its album.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_genre", name: "Guess the Genre", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Classify tracks using the server library metadata.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_decade", name: "Guess the Decade", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify a track\u2019s release decade.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_year", name: "Guess the Year", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Estimate the release year from a song clip.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_music_video", name: "Guess the Music Video", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify music videos available in your library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_instrument", name: "Guess the Instrument", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify featured instruments from audio clips.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_cover_artist", name: "Guess the Cover Artist", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify who performed a cover version.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_original", name: "Guess the Original", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Match a cover to the original recording.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "one_second_song", name: "1-Second Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Name a song from a one-second clip.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "three_second_song", name: "3-Second Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Name a song from a three-second clip.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "five_second_song", name: "5-Second Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Name a song from a five-second clip.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "ten_second_song", name: "10-Second Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Name a song from a ten-second clip.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "first_note", name: "First Note", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify a song from its opening note.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "first_beat", name: "First Beat", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify a song from its opening beat.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "first_word", name: "First Word", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify a song from the first word heard.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "fastest_guess", name: "Fastest Guess", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Award more points for faster correct song answers.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "finish_lyrics", name: "Finish the Lyrics", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Complete short lyric prompts from licensed or user-provided text.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "missing_lyrics", name: "Missing Lyrics", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Fill missing lyric segments.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "next_word", name: "Next Word", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Predict the next word in a lyric prompt.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "next_line", name: "Next Line", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Choose what comes next in a song.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "lyrics_scramble", name: "Lyrics Scramble", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Reorder a short text prompt into the correct sequence.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "who_sang_line", name: "Who Sang This Line?", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Match lyric prompts to the artist and track.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "lyrics_multiple_choice", name: "Lyrics Multiple Choice", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Select the correct continuation from answer options.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "wrong_lyrics", name: "Wrong Lyrics", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Spot the deliberately altered line.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "continue_song", name: "Continue the Song", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Choose the next segment from several options.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "music_timeline", name: "Music Timeline", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Place songs in release-date order.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "which_song_first", name: "Which Song Came First?", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Compare release years for two tracks.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "higher_lower_year", name: "Higher/Lower Release Year", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Guess which song was released earlier or later.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "higher_lower_streams", name: "Higher/Lower Streams", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Compare stream counts when reliable metadata is available.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "artist_vs_artist", name: "Artist vs Artist", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Compare artists through themed questions or votes.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "album_vs_album", name: "Album vs Album", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Compare albums through trivia or group voting.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_sample", name: "Guess the Sample", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify the source track behind a sample.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "name_that_cover", name: "Name That Cover", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify the song from cover artwork.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "one_hit_wonder", name: "One-Hit Wonder", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Identify artists from breakout hits.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "music_connections", name: "Music Connections", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Find the shared musical connection between clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "song_battle", name: "Song Battle", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Vote or score paired songs from your library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_intro", name: "Best Intro", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Compare and vote on song intros.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_chorus", name: "Best Chorus", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Compare and vote on choruses.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_bassline", name: "Best Bassline", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Compare bassline clips.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_guitar", name: "Best Guitar", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Compare guitar performances.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_party_song", name: "Best Party Song", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Build a group-voted party-song ranking.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_workout_song", name: "Best Workout Song", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Vote for the best workout tracks.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_movie_song", name: "Best Movie Song", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Vote on soundtrack tracks.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "best_song_decade", name: "Best Song of the Decade", category: GameCategory.music, minPlayers: 2, maxPlayers: 16, description: "Run decade-based song brackets.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_movie", name: "Guess the Movie", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a movie from metadata, stills, or licensed prompts.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_tv_show", name: "Guess the TV Show", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a show from the user\u2019s own TV library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_actor", name: "Guess the Actor", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify an actor from cast metadata or authorized stills.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_actress", name: "Guess the Actress", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify an actor from cast metadata or authorized stills.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_character", name: "Guess the Character", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify characters connected to available media metadata.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_director", name: "Guess the Director", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Match a film or show to its director.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_franchise", name: "Guess the Franchise", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify the franchise from linked titles.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_episode", name: "Guess the Episode", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify episodes using episode metadata or authorized prompts.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_scene", name: "Guess the Scene", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a scene from an authorized still or crop.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "guess_location", name: "Guess the Location", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a filming/story location from authorized clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_soundtrack_guess", name: "Movie Soundtrack Guess", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Name films from soundtrack entries in your music library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "tv_theme_guess", name: "TV Theme Guess", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Name shows from theme songs in your music library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_quote", name: "Movie Quote", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a film from short authorized quote prompts.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "tv_quote", name: "TV Quote", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a show from short authorized quote prompts.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "who_said_it", name: "Who Said It?", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Match a short prompt to a character.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_sound_effect", name: "Movie Sound ID", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a movie from authorized sound effects.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "show_sound_effect", name: "TV Sound ID", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a show from authorized audio cues.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "blurred_scene", name: "Blurred Scene", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Reveal a scene gradually and identify the title.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "zoomed_scene", name: "Zoomed-In Scene", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a title from a cropped still.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "pixelated_movie", name: "Pixelated Movie", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a film from a pixelated poster/still.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "silhouette_character", name: "Silhouette Character", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify a character from a silhouette.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "actor_face", name: "Actor Face", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify performers using appropriately licensed artwork.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_poster_puzzle", name: "Movie Poster Puzzle", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Reassemble poster tiles and identify the title.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "missing_poster", name: "Missing Poster", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify the title from partially hidden poster art.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_trivia", name: "Movie Trivia", category: GameCategory.trivia, minPlayers: 1, maxPlayers: 16, description: "Generate questions from movie metadata and curated trivia.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "tv_trivia", name: "TV Trivia", category: GameCategory.trivia, minPlayers: 1, maxPlayers: 16, description: "Generate questions from show, season, and episode metadata.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "release_year", name: "Release Year", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Guess the release year from library metadata.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "actor_connections", name: "Actor Connections", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Connect titles through shared cast members.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "director_connections", name: "Director Connections", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Connect titles through director credits.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_timeline", name: "Movie Timeline", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Order films chronologically.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "sequel_or_original", name: "Sequel or Original?", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Classify a title within its franchise.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "remake_or_original", name: "Remake or Original?", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Distinguish remakes from original works.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "movie_or_tv", name: "Movie or TV?", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Classify the source as film or television.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "which_movie_first", name: "Which Came First?", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Compare release dates for two titles.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "box_office_higher_lower", name: "Box Office Higher/Lower", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Compare sourced box-office data where available.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "runtime_higher_lower", name: "Runtime Higher/Lower", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Compare runtime from library metadata.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "tv_show_emoji", name: "TV Show Emoji", category: GameCategory.movieTv, minPlayers: 1, maxPlayers: 16, description: "Identify shows from emoji clues.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "family_feud", name: "Family Feud", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Team survey-answer rounds with host controls.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "survey_says", name: "Survey Says", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Reveal ranked survey answers and award team points.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "most_likely_to", name: "Most Likely To", category: GameCategory.party, minPlayers: 3, maxPlayers: 16, description: "Vote privately, then reveal group results.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "would_you_rather", name: "Would You Rather?", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Vote between two options and compare the room.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "never_have_i_ever", name: "Never Have I Ever", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Opt-in prompt rounds with configurable family-safe content.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "two_truths_lie", name: "Two Truths and a Lie", category: GameCategory.party, minPlayers: 3, maxPlayers: 16, description: "Players submit three statements and others spot the bluff.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "truth_or_bluff", name: "Truth or Bluff", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Distinguish real answers from invented ones.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "guess_who", name: "Guess Who", category: GameCategory.party, minPlayers: 2, maxPlayers: 8, description: "Use yes/no questions to identify a secret character.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "hot_seat", name: "Hot Seat", category: GameCategory.party, minPlayers: 3, maxPlayers: 16, description: "One player answers while the group predicts or scores.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "whos_most_likely", name: "Who\u2019s Most Likely?", category: GameCategory.party, minPlayers: 3, maxPlayers: 16, description: "Group voting with customizable prompts.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "act_it_out", name: "Act It Out", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Act out timed prompts for teammates.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "sound_effects", name: "Sound Effects", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Create or identify sound effects.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "impression_challenge", name: "Impression Challenge", category: GameCategory.party, minPlayers: 2, maxPlayers: 16, description: "Perform a voice or character impression; score by group vote.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "dance_challenge", name: "Dance Challenge", category: GameCategory.danceRhythm, minPlayers: 1, maxPlayers: 16, description: "Perform a short dance challenge with phone motion input.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "lip_sync_battle", name: "Lip Sync Battle", category: GameCategory.danceRhythm, minPlayers: 1, maxPlayers: 16, description: "Perform a lip-sync round to music from the server library.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "karaoke_battle", name: "Karaoke Battle", category: GameCategory.music, minPlayers: 1, maxPlayers: 16, description: "Compete on timing and pitch when licensed lyrics are available.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true),
    GameDefinition(id: "music_racing", name: "Music Racing", category: GameCategory.racing, minPlayers: 1, maxPlayers: 12, description: "Choose song, vehicle, track theme, and race mode; music references server song IDs.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "beat_saber_style", name: "Beat/Rhythm Motion Challenge", category: GameCategory.danceRhythm, minPlayers: 1, maxPlayers: 8, description: "Slice/strike rhythm targets using calibrated phone or controller motion.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "dance_coach", name: "Dance / Choreography", category: GameCategory.danceRhythm, minPlayers: 1, maxPlayers: 16, description: "Follow a dance coach, pictograms, combos, gold moves, and song ratings.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "rhythm_challenge", name: "Rhythm Challenge", category: GameCategory.danceRhythm, minPlayers: 1, maxPlayers: 16, description: "Hit timed cues and build accuracy combos from library tracks.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "dance_battle", name: "Dance Battle", category: GameCategory.danceRhythm, minPlayers: 2, maxPlayers: 16, description: "Compare dance-session scores in versus or team mode.", isPlayable: false, platformScope: GamePlatformScope.allScreens, usesServerMedia: true, supportsPhoneMotionController: true),
    GameDefinition(id: "motion_sports", name: "Motion Sports", category: GameCategory.sports, minPlayers: 1, maxPlayers: 8, description: "Phone motion-controller foundation for bowling, tennis, and other motion games.", isPlayable: false, platformScope: GamePlatformScope.allScreens, supportsPhoneMotionController: true),
    GameDefinition(id: "cross_game_tournament", name: "Cross-Game Tournament", category: GameCategory.tournament, minPlayers: 2, maxPlayers: 64, description: "Create a schedule of different games with per-game scoring and separate tournament points.", isPlayable: false, platformScope: GamePlatformScope.allScreens),
    GameDefinition(id: "crossover_arena_fighter", name: "Crossover Arena Fighter", category: GameCategory.fighting, minPlayers: 1, maxPlayers: 8, description: "Platform fighter architecture for characters, moves, stats, and stages. Protected franchise content requires distribution rights.", isPlayable: false, platformScope: GamePlatformScope.consolePcOnly, usesServerMedia: true),
  ];

  static const difficultyLevels = <String>[
    'easy',
    'medium',
    'hard',
    'expert',
    'master',
    'grandmaster',
    'random',
  ];

  static const variantDefinitions = <String, List<GameVariantDefinition>>{
    'chess': [
      GameVariantDefinition(id: 'standard', name: 'Standard Chess', description: 'Full legal chess with check, checkmate, castling, en passant and promotion.'),
      GameVariantDefinition(id: 'rapid', name: 'Rapid Chess', description: 'Standard chess with a faster clock configuration.'),
    ],
    'checkers': [
      GameVariantDefinition(id: 'american', name: 'American Checkers', description: '8×8 checkers with mandatory captures.'),
      GameVariantDefinition(id: 'international', name: 'International Draughts', description: '10×10 draughts with longer-range kings.'),
    ],
    'connect4': [
      GameVariantDefinition(id: 'standard', name: 'Classic 7×6', description: 'Four pieces in a row wins.'),
      GameVariantDefinition(id: 'popout', name: 'PopOut', description: 'Drop pieces or pop the bottom piece from a column.'),
      GameVariantDefinition(id: 'five_in_row', name: 'Five in a Row', description: 'A larger win condition for advanced play.'),
    ],
    'ludo': [
      GameVariantDefinition(id: 'classic', name: 'Classic Ludo', description: 'Four pieces per player, one die and the classic home path.'),
      GameVariantDefinition(id: 'quick', name: 'Quick Ludo', description: 'Shorter race for faster matches.'),
    ],
    'snakes_ladders': [
      GameVariantDefinition(id: 'classic_100', name: 'Classic 1–100', description: '100-square board with snakes and ladders.'),
      GameVariantDefinition(id: 'short_64', name: 'Short 1–64', description: 'Compact board for a faster game.'),
    ],
    'monopoly': [
      GameVariantDefinition(id: 'classic', name: 'Classic Monopoly', description: 'Property purchases, rent, taxes, cards, jail and two dice.'),
      GameVariantDefinition(id: 'short', name: 'Short Game', description: 'Condensed property values and faster play.'),
    ],
    'sorry': [
      GameVariantDefinition(id: 'classic', name: 'Classic Sorry!', description: 'Card-driven pawn race with bumping and slides.'),
      GameVariantDefinition(id: 'simplified', name: 'Simplified Sorry!', description: 'Shorter track and faster card-driven play.'),
    ],
    'backgammon': [
      GameVariantDefinition(id: 'standard', name: 'Standard Backgammon', description: '24 points, two dice, hits, bar and bearing off.'),
      GameVariantDefinition(id: 'nackgammon', name: 'Nackgammon', description: 'Alternate starting position with the same core rules.'),
    ],
    'battleship': [
      GameVariantDefinition(id: 'classic', name: 'Classic Fleet', description: 'Standard fleet placement and hidden-grid targeting.'),
      GameVariantDefinition(id: 'salvo', name: 'Salvo', description: 'Advanced mode allowing multiple shots per turn.'),
    ],
    'solitaire': [
      GameVariantDefinition(id: 'klondike_draw1', name: 'Klondike Draw 1', description: 'Classic Klondike with one-card draw.'),
      GameVariantDefinition(id: 'klondike_draw3', name: 'Klondike Draw 3', description: 'Classic Klondike with three-card draw.'),
    ],
    'tripeaks': [GameVariantDefinition(id: 'classic', name: 'Classic TriPeaks', description: 'Clear three peaks by playing one rank above or below the waste card.')],
    'pyramid': [GameVariantDefinition(id: 'classic', name: 'Classic Pyramid', description: 'Remove exposed card pairs totaling 13.')],
    'freecell': [GameVariantDefinition(id: 'classic', name: 'Classic FreeCell', description: 'Four free cells and four foundations.')],
    'spider': [
      GameVariantDefinition(id: 'one_suit', name: '1 Suit Spider', description: 'Beginner Spider using one suit.'),
      GameVariantDefinition(id: 'two_suit', name: '2 Suit Spider', description: 'Intermediate Spider using two suits.'),
      GameVariantDefinition(id: 'four_suit', name: '4 Suit Spider', description: 'Expert Spider using all four suits.'),
    ],
    'continental': [GameVariantDefinition(id: 'classic', name: 'Classic Continental', description: 'Progressive rummy rounds with sets and runs.')],
    'la_viuda': [GameVariantDefinition(id: 'classic', name: 'Classic La Viuda', description: 'Traditional trick/card-play configuration.')],
    'uno_like': [
      GameVariantDefinition(id: 'classic', name: 'Classic UNO', description: 'Match by color or number and use action cards.'),
      GameVariantDefinition(id: 'speed', name: 'Speed UNO', description: 'Faster turns with accelerated play.'),
    ],
    'texas_holdem': [GameVariantDefinition(id: 'no_limit', name: 'No-Limit Hold’em', description: 'Play-money Texas Hold’em with standard community cards.')],
    'blackjack': [
      GameVariantDefinition(id: 'classic', name: 'Classic Blackjack', description: 'Dealer stands on 17 with standard blackjack payouts.'),
      GameVariantDefinition(id: 'european', name: 'European Blackjack', description: 'European-style hole-card rules.'),
    ],
    'baccarat': [
      GameVariantDefinition(id: 'punto_banco', name: 'Punto Banco', description: 'Standard banker/player baccarat rules.'),
    ],
    'sudoku': [
      GameVariantDefinition(id: 'mini_4x4', name: 'Mini Sudoku 4×4', description: '4×4 grid using digits 1–4.'),
      GameVariantDefinition(id: 'classic_9x9', name: 'Classic Sudoku 9×9', description: 'The standard 9×9 Sudoku board.'),
      GameVariantDefinition(id: 'jigsaw_9x9', name: 'Jigsaw / Irregular / Squiggly Sudoku', description: 'Irregular connected polyomino regions replace standard 3×3 boxes.'),
      GameVariantDefinition(id: 'windoku_9x9', name: 'Windoku / Hyper Sudoku', description: 'Classic 9×9 plus four extra shaded 3×3 regions.'),
      GameVariantDefinition(id: 'killer_9x9', name: 'Killer Sudoku', description: 'Dotted cages have target sums and cannot repeat digits.'),
      GameVariantDefinition(id: 'x_9x9', name: 'Diagonal / X Sudoku', description: 'Both main diagonals must also contain 1–9.'),
      GameVariantDefinition(id: 'consecutive_9x9', name: 'Consecutive Sudoku', description: 'Marked adjacent cells must contain consecutive values.'),
      GameVariantDefinition(id: 'nonconsecutive_9x9', name: 'Non-Consecutive Sudoku', description: 'Orthogonally adjacent cells may not be consecutive.'),
      GameVariantDefinition(id: 'even_odd_9x9', name: 'Even–Odd Sudoku', description: 'Marked cells are restricted to even or odd values.'),
      GameVariantDefinition(id: 'greater_than_9x9', name: 'Greater-Than Sudoku', description: 'Inequality signs constrain adjacent cells.'),
      GameVariantDefinition(id: 'arrow_thermo_9x9', name: 'Arrow & Thermo Sudoku', description: 'Arrow paths use sums and thermometers increase from bulb to tip.'),
      GameVariantDefinition(id: 'wordoku_9x9', name: 'Wordoku', description: 'Letters replace digits and form a hidden nine-letter word.'),
      GameVariantDefinition(id: 'color_9x9', name: 'Color Sudoku', description: 'Values are represented by distinct colors/symbols.'),
      GameVariantDefinition(id: 'mega_25x25', name: 'Mega / Giant Sudoku 25×25', description: '25×25 grid using 0–9 and A–O as 25 symbols.'),
    ],
    'jigsaw': [GameVariantDefinition(id: 'irregular_9x9', name: 'Irregular / Squiggly 9×9', description: 'Nine irregular connected regions.')],
    'word_search': [GameVariantDefinition(id: 'classic', name: 'Classic Word Search', description: 'Find words horizontally, vertically, diagonally and backwards.')],
    'minesweeper': [
      GameVariantDefinition(id: 'beginner', name: 'Beginner', description: 'Small board with fewer mines.'),
      GameVariantDefinition(id: 'intermediate', name: 'Intermediate', description: 'Larger board with more mines.'),
      GameVariantDefinition(id: 'expert', name: 'Expert', description: 'Large board with high mine density.'),
    ],
    'mahjong': [GameVariantDefinition(id: 'classic', name: 'Classic Mahjong Solitaire', description: 'Match exposed identical tile pairs until the layout is cleared.')],
    'dominoes': [GameVariantDefinition(id: 'classic', name: 'Classic Dominoes', description: 'Match equal ends and play until a player empties their hand or the board blocks.')],
    'draw_dominoes': [GameVariantDefinition(id: 'draw', name: 'Draw Dominoes', description: 'Draw from the boneyard when you cannot play.')],
    'all_fives': [GameVariantDefinition(id: 'all_fives', name: 'All Fives', description: 'Score when the open ends total a multiple of five.')],
    'chicken_foot': [GameVariantDefinition(id: 'classic', name: 'Chicken Foot', description: 'Build branches from doubles until the chicken foot opens.')],
    'mexican_train': [GameVariantDefinition(id: 'classic', name: 'Mexican Train', description: 'Build personal and shared trains from the central double.')],
    'rummikub': [GameVariantDefinition(id: 'classic', name: 'Classic Rummikub', description: 'Build valid groups and runs while managing a rack of tiles.')],
    'snake': [GameVariantDefinition(id: 'classic', name: 'Classic Snake', description: 'Grow the snake by eating food without hitting walls or yourself.')],
    'bubble': [GameVariantDefinition(id: 'classic', name: 'Classic Bubble Shooter', description: 'Match groups of same-color bubbles and clear the board.')],
    'bejeweled_like': [GameVariantDefinition(id: 'classic', name: 'Classic Gem Match', description: 'Swap adjacent gems to create matches of three or more.')],
    'gravity_block': [GameVariantDefinition(id: 'classic', name: 'Gravity Block', description: 'Place falling blocks and clear complete lines.')],
    'gem_drop': [GameVariantDefinition(id: 'classic', name: 'Gem Drop', description: 'Drop matching gems and clear chains before the board fills.')],
    'queens': [GameVariantDefinition(id: 'classic', name: 'Queens', description: 'Place one queen in each row and column without diagonal attacks.')],
    'tango': [GameVariantDefinition(id: 'classic', name: 'Tango', description: 'Satisfy paired equality and inequality constraints.')],
    'patches': [GameVariantDefinition(id: 'classic', name: 'Patches', description: 'Fit pieces into the board while satisfying placement constraints.')],
    'zip': [GameVariantDefinition(id: 'classic', name: 'Zip', description: 'Connect matching endpoints through a complete path.')],
    'wend': [GameVariantDefinition(id: 'classic', name: 'Wend', description: 'Word-path puzzle with connected letter routes.')],
    'pinpoint': [GameVariantDefinition(id: 'classic', name: 'Pinpoint', description: 'Identify the hidden category from progressively revealed clues.')],
    'crossclimb': [GameVariantDefinition(id: 'classic', name: 'Crossclimb', description: 'Solve a connected word ladder/grid using crossing clues.')],
  };

  List<GameVariantDefinition> variantsFor(String gameId) =>
      variantDefinitions[gameId] ?? const <GameVariantDefinition>[];

  GameVariantDefinition variant(String gameId, String variantId) {
    final options = variantsFor(gameId);
    return options.firstWhere(
      (item) => item.id == variantId,
      orElse: () => options.isEmpty
          ? const GameVariantDefinition(id: 'standard', name: 'Standard')
          : options.first,
    );
  }

  List<GameDefinition> byCategory(GameCategory category) =>
      definitions.where((game) => game.category == category).toList(growable: false);

  GameDefinition byId(String id) => definitions.firstWhere(
        (game) => game.id == id,
        orElse: () => definitions.first,
      );
}
