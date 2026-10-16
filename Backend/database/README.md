# Database

## Social profile presence and account chats

Apply `social_v2_migration.sql`, `social_chat_presence.sql`, and then
`social_presence_activity_types.sql` in order. The last migration expands the
presence activity categories used by the Home profile strip (watching,
listening, shopping, food ordering, and Hey Marathon planning). Profile-to-profile
and account-group conversations use the existing `social_conversations` and
`social_conversation_members` tables; no media files are copied into Supabase.

Contains the backend persistence abstraction and database migrations for accounts, sessions, media, groups, reviews, ratings, ARM ingestion metadata, and marketplace associations.

## Persistence responsibilities

The database layer provides storage and access for:

* Accounts, profiles, sessions, authentication state, and account preferences.
* Media-library records and playback-related metadata.
* Groups, group memberships, recommendations, watch activity, and reviews.
* External/provider rating snapshots.
* Private profile-specific media ratings.
* ARM ingestion jobs and physical-media provenance.
* Physical releases, discs, and individual disc contents.
* Canonical music recordings and their relationships to music releases/tracks.
* Lightweight global marketplace entity associations.

## Ratings

External ratings and personal profile ratings are intentionally stored separately.

Provider ratings are cached snapshots containing information such as:

* Provider name.
* Rating type.
* Rating value and scale.
* Vote count when available.
* Source URL.
* Last update time.

Profile ratings represent an individual profile's personal 0.5-to-5-star rating in half-star increments.

Provider ratings, profile ratings, and public reviews are not combined into a single score.

## ARM and physical-media provenance

ARM ingestion preserves the distinction between a physical release and the media contained on it.

The persistence model can represent:

```text
Physical Release
└── Physical Disc
    └── Disc Content
        └── Library Media
```

This allows a release to contain multiple discs and allows a disc to contain multiple independent pieces of content.

For example, a bonus-features disc can contain:

* Deleted scenes.
* Trailers.
* Commentaries.
* Interviews.
* Featurettes.
* Other supplemental material.

Bonus content remains associated with the physical disc without being incorrectly represented as the primary movie or show.

The database also preserves the original disc/release provenance so imported library media can be traced back to its physical source.

## Music identity

Music releases and canonical recordings are separate entities.

A release may contain tracks that reference the same canonical recording found on another release:

```text
Artist Album
└── Track → Recording A

Soundtrack
└── Track → Recording A
```

The same recording therefore does not need to become a duplicate canonical song merely because it was discovered on another physical release.

Recording identity should be established using reliable identifiers and metadata such as:

* ISRC.
* Audio fingerprint.
* Verified metadata.
* Other provider or catalog identifiers.

A title alone should not automatically merge two recordings.

## Marketplace associations

The global marketplace database stores only lightweight entity metadata.

It may associate entities such as:

* Movies.
* Shows.
* Music releases.
* Recordings.
* Artists.
* Collections.
* Other supported marketplace entities.

Physical media and private library files remain on the owning account's server.

The global marketplace association index is therefore not a replacement for the account's local media database. It provides a discoverability/association layer that can later support privacy and public-visibility controls.

## Local versus global data

The architecture separates account-server data from global marketplace metadata:

```text
Account Server
├── Media files
├── Library metadata
├── Physical release/disc provenance
├── ARM jobs
├── Profile ratings
└── Private account data

Global Marketplace
└── Lightweight shop entity associations
```

Credentials, passwords, API keys, and media files are not stored in the global marketplace association index.

## Migrations

SQL migration files in this directory define durable database structures.

Migrations should:

* Be safe to run against an existing installation where practical.
* Avoid storing secrets or media files.
* Preserve existing account and library data.
* Keep external ratings separate from personal ratings.
* Preserve physical-media provenance.
* Avoid automatically merging distinct media solely because their titles match.
* Keep global marketplace metadata separate from private account-server media.

The in-memory database implementation may be used for local development and tests, while the durable database/store implementation is responsible for production persistence.

## Household chat and guardian controls

Apply `social_household_parental_controls.sql` after the base streaming, live persistence, social-home, and social V2 migrations. It creates the per-account household group conversation and foundational guardian/content access records. Add verified dates of birth and guardian relationships using a trusted management flow. Only guardian friend-request approval is wired in the current UI; guardian relationship management, community review screens, profile privacy restrictions, and enforcement of title/lyrics restrictions across every query/playback path still need implementation before parental controls can be described as complete.

For databases that already had the retired live-sports feature, apply `remove_sports_feature.sql` after deploying the code that no longer references those tables.

## Food & Delivery restaurant messaging

Apply `food_delivery.sql` first, then apply `food_messaging.sql` to the same Supabase database before deploying the matching Flutter/backend changes. The messaging migration adds recipe ingredient/allergen fields to menu items and creates customer-to-restaurant conversation/message tables. Those tables have row-level security enabled and are intended to be accessed only through the authenticated backend using the server-side service role; never put the service-role key in Flutter.

Restaurant ingredient answers are staff-confirmed statements, not AI-generated allergy assurances. The UI captures ingredient presence, removability, and cross-contact handling separately, and tells customers not to rely on the response as a medical guarantee when the kitchen cannot confirm safe preparation.

## Restaurant profiles, reviews, contacts, and watch-party menus

For a fresh database, `food_delivery.sql` includes the restaurant contact/hours and menu ingredient/theme fields. Then apply `food_messaging.sql` and `food_restaurant_profiles_reviews_themes.sql` in that order. For an existing database, the two add-on migrations use `IF NOT EXISTS` where appropriate and preserve current restaurant/menu data.

The profile feature stores a human-readable opening-hours summary and a structured weekday schedule (24-hour `HH:MM` values or explicitly closed/all-day). Examples displayed to customers include `Mon-Fri 9:00 AM-5:00 PM; Sat-Sun Closed` and `24/7`. It currently does not compute a time-zone-aware real-time `Open now` state; that must use an explicit restaurant timezone before being relied on operationally.

Restaurant ratings are individual 1–5 star reviews. The database recalculates the aggregate average and count from the reviews table. A verified-order indicator is derived server-side from completed order records and cannot be set by the client. Restaurant contact methods are configured independently (call, SMS, iMessage, WhatsApp, email, and website); actual availability depends on the customer's device/app and the contact data provided by the restaurant.

The themed-menu feature supplies food ideas for watch parties (including wizarding-fantasy and superhero-inspired marathons) but it does not add invented dishes or prices to a restaurant's real menu. Owners must create/price each actual dish, declare ingredients/allergens, then select those menu items in a themed collection. Franchise-inspired content is not represented as officially affiliated unless appropriate licensing exists.

## Unified localization and disc-import workflows

The Flutter locale controller updates the root app locale and profile preference. Existing `UniversalText` and selected media metadata paths support automatic translations through the optional `translate-text` Supabase Edge Function. To guarantee every label across all existing pages is localized, remaining literal `Text` widgets still need a systematic migration to keyed resources/`UniversalText`, followed by locale-by-locale UI tests. Never overwrite original disc metadata with translated strings.

The ARM import review and episode-order components preserve source metadata and resolve each episode to a canonical series/season/episode identity. Import order and disc number are not watch-order keys. Run the ARM-focused tests and confirm all uncertain matches before finalizing an import. Actual extraction of menus, chapters, tracks, subtitles, commentary, and bonus titles still depends on the deployed disc-ripping/ARM toolchain and the capabilities/legal accessibility of each disc.

The project intentionally excludes gaming features. The application focuses on movies/TV/music, social, shopping, food delivery, media importing, and Hey Media AI.

## Social messaging encryption and pinned messages

For an existing database using the social messaging routes, apply `social_message_controls_and_e2ee.sql` after the base social/chat migrations. It adds pinned-message fields and storage for public per-device E2EE keys. Private encryption keys must remain on user devices.

For media attachments on post comments, apply `social_post_comment_media_reference.sql` after the social post/comments schema. This adds an optional JSONB attachment reference; the backend must validate account/profile ownership before accepting a reference.

## Streaming experience telemetry (additive)

`streaming_experience_telemetry.sql` creates QoE event, discovery feedback, and profile preference tables. Review and apply it as an additive migration only after checking the live schema. These tables intentionally have RLS enabled and no `anon`/`authenticated` write policies: the project uses application account/profile identifiers, so a trusted backend must validate ownership before accessing these rows with the service role. The Flutter diagnostics screen presently stores its bounded QoE log on the device; remote ingestion is not wired until that validated endpoint is implemented.

## Production readiness and privacy foundation

Apply `production_readiness_and_privacy.sql` after the base account/profile and social migrations and after taking a verified backup. The new tables are RLS-enabled and granted only to `service_role`; there are intentionally no anon/authenticated client policies because account/profile identifiers are application IDs, not assumed to equal `auth.uid()`. A trusted backend route must validate authenticated account membership before using service-role writes.
