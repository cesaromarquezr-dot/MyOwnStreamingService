# Owned Media Experience migrations

Apply the SQL files in this order in the project's Supabase SQL editor or migration runner:

1. `media_experience.sql` — creates the account/profile-scoped record table.
2. `media_collections.sql` — indexes saved disc, box-set, special, and playlist collections.
3. `theater.sql` — indexes private at-home screening history.
4. `kiosk_inventory.sql` — indexes kiosk preferences and play-session history.

The server accesses this table with its server-side Supabase service role after authenticating the app account and checking the selected profile. Do not ship the service-role key in Flutter or create a public/anonymous policy for this table.

These features are for content already in the account's owned library. The schema intentionally has no rental, return, checkout, admission-charge, payment, or sales records.
