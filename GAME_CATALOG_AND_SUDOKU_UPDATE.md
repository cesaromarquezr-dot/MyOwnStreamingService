# Game catalog and game-engine update

- Game variant definitions are now owned by `lib/core/models/game_catalog.dart`.
- All game launch screens expose the common difficulty set: Easy, Medium, Hard, Expert, Master, Grandmaster, Random.
- `games.dart` reads variants from the catalog instead of maintaining a duplicate variant switch.
- Sudoku defaults to Classic 9x9.
- Jigsaw defaults to Irregular/Squiggly 9x9.
- Sudoku variants implemented in the board engine include Mini 4x4, Classic 9x9, Jigsaw/Irregular, Windoku/Hyper, Killer, Diagonal/X, Consecutive, Non-Consecutive, Even/Odd, Greater-Than, Arrow & Thermo, Wordoku, Color Sudoku, and Mega/Giant 25x25.
- Mega/Giant Sudoku uses exactly 25 symbols: 0-9 and A-O.
- Jigsaw uses connected irregular regions.
- Windoku uses four additional 3x3 regions.
- Killer generates cage targets from the solved grid and enforces cage sums/no-repeat rules.
- X Sudoku enforces both main diagonals.
- Consecutive, Non-Consecutive, Even/Odd, Greater-Than, Arrow/Thermo constraints are validated during entry.
- Wordoku displays the nine-letter STREAMING symbol set; Color Sudoku displays value colors.
- Existing animated dice and dedicated board routing remain intact.

Flutter/Dart SDK was not available in the build environment, so `flutter analyze` could not be executed here.
