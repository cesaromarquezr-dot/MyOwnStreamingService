# Account Profile Activity and Messaging

## User experience

- Profile selection is a separate full-screen flow; the global navbar is hidden while it is visible.
- Creating a profile only saves it. It does not activate it or navigate Home. The user chooses a profile explicitly from the selector.
- Selecting a profile from the main app resets navigation to that profile's Home screen.
- Home's account activity strip intentionally excludes the current profile. It lists other profiles in the same account, shows a green glow for a recently active profile, exposes an exact elapsed-time tooltip, and renders the latest activity text.
- The profile strip's Message action starts a profile-to-profile conversation and opens it in Friends > Messages.
- Friends has a top-right household group chat action that opens the account's single automatically provisioned household conversation. Other friend and cross-account group chats remain separate.
- More > Account Recommendations lets any profile recommend a movie, show, episode, song, or album for an account-wide vote. A majority YES places it on the shared wishlist; a non-YES outcome places it on each participating profile's wishlist. Matching imported media clears the recommendation from wishlists.
- Accounts support up to 10 profiles. Profiles can vote once each on an account recommendation.

## Account recommendation behavior

Recommendations are open for the configured voting period (24 hours from the current UI). A strict YES majority approves the recommendation; a tie or no votes is treated as not approved. Approved recommendations appear in the account wishlist. Other outcomes appear in each eligible profile's wishlist. When an imported server-library item matches by media ID or normalized title and type, it is marked acquired and removed from those wishlists.

Apply `lib/supabase/migrations/20261102_profile_recommendation_wishlist.sql` to persist per-profile recommendation wishlists.

## Presence and activity

Presence lives in `social_profile_presence` and stores only account/profile IDs, status, activity category/text and last-seen timestamps. The Home strip refreshes from the authenticated backend every 30 seconds. If the API is unavailable, it falls back to local profile cards without claiming their presence is active.

Activities currently set by the client include watching media, listening to an album/track or playlist item, shopping, ordering food, planning a Hey Marathon, watching a collection item, and watching a TV-channel entry. Text is capped at 160 characters by the player/backend contract.

## Database rollout

Apply these SQL files in order on the backend's Supabase database:

1. `Backend/database/consolidated_social.sql` (if the social V2 messaging schema has not already been installed)
2. `Backend/database/consolidated_social.sql`
3. `Backend/database/consolidated_social.sql`

The new activity-type migration only replaces the CHECK constraint that mentions `activity_type`; it leaves the availability constraint intact. Run it in a staging database first and review the migration against the live schema.

## Validation limits

The changes were source-reviewed and archive-integrity checked. Flutter/Dart analysis and widget tests could not be executed in the packaging environment because the Flutter/Dart SDK is unavailable. The SQL migrations are included but have not been applied to a live Supabase instance.
