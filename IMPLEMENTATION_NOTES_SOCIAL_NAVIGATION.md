# MyOwnStreamingService — social navigation and profile feature pass

This update applies a best-effort subset of the requested UX and backend work to the uploaded project. The Flutter interface keeps its existing design language and feature architecture; new social style names are generic design terms rather than other products' branding.

## Included changes

- Main Home, Library, and Friends navigation routes now have distinct route names and update the selected page immediately, so the contextual Customize action should point to the page selected on the first click.
- The existing onboarding route state continues to hide the global navbar during server selection and profile selection; the navbar is shown only after a profile is selected and the main screen opens.
- Added independent social appearance settings for Feed, Profile Page, Communities, Friends, Messages, and Reels, with generic style choices, Top/Left/Right section navigation, custom section ordering, timeline/post-card layout, and sorting/filter preferences. Every theme choice now opens a gallery with a detailed description and a live miniature profile/post preview. The previews visually demonstrate palettes, contrast, border weight, spacing, corner shape, depth, and accent controls. The social surfaces use each theme's palette, brightness, density, card shape, chip, input, and button treatments; highly specific effects such as blur across every real content card may still need additional per-widget polish.
- Connected the social preferences to the social surface; added friend list/card view and sort orders, community list/cards with All/Joined/Created filters and Movies/Shows/Music categories, profile post sorting, and friend/post counters.
- Friend presence data is surfaced in avatars: green for online, red for occupied while watching/listening, and no glow when offline, with a relative last-seen tooltip. Main-screen presence heartbeat keeps last-seen current without overwriting playback activity.
- Kept the existing Hey Media assistant and pre-existing messaging, reels, polls, recommendations, and conversation features.
- The More menu groups Account Members/Home Server, Shop/Food Delivery, and Radio/My TV. Import / Rip is available as its own More card and as a button from Home Server; the import screen remains a separate route with the global navbar hidden.
- Member invitations can open the system SMS/iMessage composer, WhatsApp, or both.
- Added a People Connections screen reachable from actor chips in media details. It computes a shortest path through cast/crew/music credits indexed in the active library and names the work that connects each pair; it does not invent connections not present in the library.
- Added a duplicate-on-server check for reviewed media imports. A duplicate title/type/year already indexed on the same server is reported as a client error rather than silently adding another record.
- Removed the dedicated live-sports feature from Flutter/backend code and removed its event/category references. The cleanup migration is retained only to remove old database objects from an installation that had them.
- Repaired the TrueNAS agent's packaged Python source, Dockerfile, dependencies, and Compose file. It now has a read-only media mount and local-network binding example.
- Added database groundwork for a per-account automatic “Home Server Profiles” group conversation (created when there are at least two active profiles and updated when profiles are added), plus guardian review tables/triggers for incoming friend requests to a supervised child profile.


## This update: theme gallery, onboarding visibility, and Import / Rip

- Added `lib/social_theme_gallery.dart`. It defines descriptions and preview tokens for all 15 social styles: Light, Dark, Minimalist, Flat, Skeuomorphic, Material, Neumorphism, Glassmorphism, High Contrast, Brand-Centric, Cyberpunk, Retro Futurism, Brutalism, Compact, and Casual. Each social section theme control now displays the selected preview and opens a scrollable gallery with a sample post, action chips, style description, and a one-tap Use action.
- Updated `lib/social_center.dart` to use the same palette tokens for the live social surface: page canvas, cards, typography colors, inputs, chips, buttons, border thickness, elevation, radius, and density.
- Updated the route observer in `lib/main.dart` so unnamed popup routes (dialogs/bottom sheets) do not become new page identities. The server-name dialog therefore remains on the server-selection state, onboarding keeps the navbar hidden, and Customize stays associated with the visible underlying page instead of a phantom modal route.
- Restored a visible `Import / Rip` card in More and exposed the same action from the Home Server dashboard. The route uses `/app/page/import`, which is excluded from global navigation, so the navbar only returns after going back to the selected profile's main page.
- The Supabase store in this package includes `answerSocialGuardianFriendRequest` and the `category` parameter on `createSocialCommunity`, matching the backend route call sites. If the same compile errors persist locally, replace the corresponding `Backend/supabase_store.dart` and `Backend/routes/supabase_sync_routes.dart` with the ones in this ZIP rather than applying the small previous patch ZIP by itself.

## Supabase migration steps

1. Deploy the updated Dart backend and Flutter app code.
2. Ensure the existing account, streaming, and social migrations are already applied, including `streaming_service.sql`, `live_persistence.sql`, `social_home.sql`, and `social_v2.sql` (or the corresponding `Backend/database/social_v2_migration.sql`).
3. Apply `Backend/database/social_household_parental_controls.sql` to the same Supabase database. The mirror is `lib/supabase/migrations/social_household_parental_controls.sql`.
4. Only if the database was previously deployed with the retired live-sports feature, apply `Backend/database/remove_sports_feature.sql` after deploying the code that no longer uses those tables. Its mirror is `lib/supabase/migrations/remove_sports_feature.sql`.
5. Configure `deploy/truenas/media-agent/.env` from `.env.example` on the NAS gateway host and follow `deploy/truenas/README.md`.

## Work that remains before the entire original feature list can be called complete

- There is not yet a UI flow to securely capture a child's birth date, verify/link legal guardians, or manage a profile's guardian relationships. Populate `date_of_birth` and `profile_guardians` only through a trusted account-management flow. The current guardian review queue only works after these records are configured and the migration is applied.
- Guardian community approval, parent-visible message review, and enforcement of per-title library and explicit-lyrics restrictions still need trusted backend routes and checks in every relevant browse, search, message, and playback path. The new schema fields/tables alone do not enforce those restrictions.
- Group-recommendation voting already exists, but the existing wishlist model is account-level; automatically adding an approved recommendation to each individual profile's separate wishlist requires a profile-scoped wishlist model/API.
- A link-based “invite this entire community into a group chat” flow still needs dedicated community invite tokens/UI.
- Actor connections only use credits already indexed in the current library; external credit ingestion and clickable nodes for traversing the full people graph are not included.
- The import/rip and remote-access implementation files were kept, but their standalone More-menu entries were removed. Further removal should only happen after confirming nothing else relies on their backend routes.

## Validation performed

- Checked relative Dart imports for missing local files: none found.
- Ran a delimiter/string scan over the changed Dart files: no mismatches reported.
- Compiled the TrueNAS agent with Python `py_compile`, parsed the Compose YAML, and verified mirrored SQL migrations are identical.
- Confirmed no live-sports references remain in ordinary Flutter/Dart/SQL feature files (the cleanup migration necessarily names legacy tables so it can drop them).
- **Flutter analysis and runtime/integration tests were not run** because the Flutter/Dart SDK is not installed in this environment. Run `flutter pub get`, `flutter analyze`, and the app/backend tests on your development machine before using this build.
- The profile tab now shows the current profile's friends/posts counts and a selectable timeline/card layout, while friends/suggestions show Friend/Add Friend states. Dedicated public pages for other profiles, their own friend/post counters, and profile-level add/remove friendship controls still need to be wired to navigation and authorization.
- The existing My TV channel configuration was left intact; the user-defined frequency of music breaks before/after/within programs still needs its own scheduling UI/player enforcement pass.
