# Entertainment Studio expansion

## Added surfaces

- **Home / More:** an Entertainment Studio entry point is linked from the Home page and More menu.
- **My TV:** quick-create presets for Movie Mix, Series Mix, Favorites, Movies + Music, and Seasonal Spotlight reuse the existing profile-aware channel engine, guide, metadata filters, favorites, seasonal ranking, and profile safety checks.
- **Smart Media Librarian:** reports missing artwork, missing descriptions, missing years, and possible same-type duplicate titles from the imported catalog. It never deletes or merges media and does not pretend to scan NAS disk SMART/ZFS state.
- **Entertainment Calendar:** profile-scoped local events and release plans; reminder delivery remains a future platform/notification integration.
- **Entertainment Journal:** private per-profile notes and optional ratings.
- **Scene Memory:** timestamped local notes, with optional insertion into the existing authenticated Supabase scene-bookmark table when the expanded-platform schema is installed.
- **Edition Manager:** records alternate cuts and physical editions while preserving underlying media binaries. Entries also use the existing collector-edition repository when authenticated.
- **Household Watchlist:** a voteable list shared across profiles on this device; when the studio-record table is deployed and users sign in with the same account, watchlist records sync under that authenticated owner. It is not a cross-account friend-group collaboration system.
- **Subtitle Workshop:** private correction/translation drafts. It does not replace source subtitles or publish content without a review workflow.
- **Fan Theory Board:** spoiler-marked theory notes.
- **Shareable Layout Presets:** safe JSON export/import for presentation descriptions only. Presets do not yet automatically apply every page setting through a universal adapter.
- **Cinema Room Mode:** profile-scoped preference presets. Hardware light control and advanced audio processing need device-specific integrations.
- **Movie Knowledge Graph:** builds a searchable connection view from existing local catalog metadata: people, music, genres, franchises and studios.
- **Media Knowledge Picker:** opens existing sourced fact/story panels for a selected library title.

## Storage server improvements

`lib/storage_dashboard.dart` now reads the authenticated `/server/storage` and `/server/arm` endpoints instead of showing hard-coded zeroes. It separates configured category usage from host filesystem capacity, shows path existence and capacity-warning states, and leaves unknown measurements explicitly unknown. The backend uses operating-system directory/file-size and volume commands, not ZFS pool health or SMART diagnostics. Add a privileged host monitoring agent for SMART, ZFS, CPU/RAM, temperatures, UPS, transcode queue, backup freshness and restore-drill results; do not expose a shell to the Flutter client.

## Supabase migration

Apply `Backend/database/consolidated_platform.sql` (mirrored at `lib/supabase/migrations/entertainment_studio_records.sql`) in staging before production. It stores user-authenticated records and applies RLS by `auth.uid()`. Regular notes are queried by their embedded `profileId`; the household watchlist intentionally spans profiles under the same signed-in account. Sharing with other accounts requires explicit membership tables, authorization policies and abuse controls.

## Verification limits

The current environment does not have the Flutter/Dart SDK. ZIP integrity, structural source checks, and script checks can be run locally; run `flutter analyze` and `flutter test` in the user's project before merging. The SQL migration has not been applied to a live Supabase environment. Real notification scheduling, cross-account collaboration, automatic scene detection, live external subtitle publishing, NAS SMART/ZFS health collection, smart lighting, and automatic application of arbitrary imported layout presets require additional platform-specific integrations and are not claimed as active here.
