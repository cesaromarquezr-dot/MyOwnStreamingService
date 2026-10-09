# Food Delivery + Games update

## Games
- Game catalog now describes dice/card mechanics and adds Monopoly/Sorry where applicable.
- Difficulty selection: Easy, Medium, Hard, Expert, Master, Grandmaster, Random.
- Dedicated boards: Ludo, Snakes & Ladders, Monopoly, Backgammon, Sorry!, Chess.
- Dice animation uses rendered pip faces; Ludo/Snakes & Ladders use one die, Monopoly/Backgammon use two dice.
- Chess engine enforces legal moves, check, checkmate, castling, en passant, and promotion.
- Sudoku/puzzle variants are carried through the game launch configuration.

## Food Delivery
- Location-based restaurant discovery.
- Menu search can match restaurant metadata and menu items (for example, "sushi").
- Restaurant menu, cart, delivery address, delivery notes, payment method selection, order placement, ETA, and tracking.
- Food Delivery is available from More and from My TV / the video player with the current viewing title as context.
- Backend routes: `/api/v1/food/*`.
- Database migration: `Backend/database/food_delivery.sql`.
- Raw card credentials are not accepted by the food-order API.
- `FOOD_PAYMENT_MOCK=true` is available only for local development; production needs a configured food-order payment adapter.

## Spider-Man 3 fictional gameplay rule
- `Rage Mode` is represented as a time-limited invulnerability/instant-defeat gameplay effect for a Spider-Man 3 symbiote experience.
