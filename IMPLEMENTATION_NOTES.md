# Streaming Service Architecture Notes

## Account and server ownership

- Each account is associated with its own home/media server in the current one-server-per-account subscription model.
- Profiles belong to accounts, not servers. Profiles may be used from any physical location.
- The account server is the source of truth for that account's physical Movies, TV Shows and Music files.
- Supabase stores identity, metadata, server indexes and coordination state; it does not store the physical media files.

## Remote importing

A browser cannot directly control a computer's optical drive. The intended flow is:

`Disc -> local Media Importer/ARM -> secure Internet transfer -> account server -> server scanner -> website library`

The existing remote-worker API is the coordination layer. A production deployment still needs the local importer process that performs the actual disc read/rip and transfers the completed output.

## Cross-account Group Chat

Group Chat is backend-coordinated and is independent of media storage. A room can contain profiles from multiple accounts.

## Cross-account Group Watch

The Group Watch invitation UI accepts local profiles plus usernames/emails from other accounts. The backend resolves cross-account identifiers and the GroupWatchService verifies that each participant's account is authorized for the requested media before the session is created.

The synchronized session carries playback state (play/pause/position and local audio/subtitle choices). Physical video files remain on the authorized account servers.

## Pricing

Default managed-server pricing is `$54.99 USD/month` or `$599.99 USD/year` for one server.

The backend pricing floor is calculated from configurable assumptions:

- $650 server hardware amortized over 36 months
- $180 storage amortized over 36 months
- 45 W average server power
- $0.16/kWh electricity
- $6/month bandwidth/operations reserve
- $4/month support reserve
- 3.5% + $0.30 payment-processing allowance
- 25% target gross margin

The retail price is never accepted from the client; the backend calculates the payment amount.

## Validation

The available container does not include the Dart or Flutter executables, so `dart format` and `flutter analyze` could not be run here. The edited source was checked for the intended changes and the output archive is structurally valid.


## Flutter to Supabase data synchronization

- Flutter initializes Supabase with the public publishable key for client-side Supabase features.
- Protected account synchronization uses the existing authenticated backend session.
- `Backend/routes/supabase_sync_routes.dart` exposes `POST /api/v1/supabase/sync/account`.
- `Backend/supabase_store.dart` writes a sanitized account snapshot using the server-only `SUPABASE_SERVICE_ROLE_KEY`.
- `AppController.syncCurrentAccountToSupabase()` is the Flutter entry point for uploading application metadata.
- Login performs a best-effort synchronization, and storage-request code synchronizes after a successful request.
- The service-role key must never be placed in Flutter, web assets, mobile builds, or desktop client configuration.
- Physical media remains on the account's home server and is never uploaded to Supabase.

## ARM optical-drive and rating integration

- ARM is treated as the ripping engine on the machine physically connected to the optical drive. The Flutter app/backend monitors ARM jobs rather than attempting to access `/dev/sr*` directly.
- ARM credentials are backend-only environment variables (`ARM_USERNAME`, `ARM_PASSWORD`).
- Provider rating credentials are backend-only. TMDB uses `TMDB_API_KEY`; IMDb and Rotten Tomatoes are optional licensed-provider URL adapters.
- Provider scores remain separate. The recommendation layer may normalize scores internally, but the UI preserves the provider's original scale and source.
- Profile ratings use 0.5-star increments from 0.5 through 5.0 and are stored separately from external scores and text reviews.


## Social V2 — chat/feed/stories/community interaction layer

The social reference UI was used as a visual/interaction reference, not as an architecture to copy.

The current social layer now separates:
- Friends: profile-scoped relationships and requests.
- Feed: friend posts plus posts from communities the active profile joined.
- Stories: short-lived 24-hour friend stories plus stories scoped to communities the active profile joined.
- My Page: posts, photos, and reviews are friend-only by default. A review can be shared to My Page, selected communities, or both; community copies remain visible only in those communities.
- Account profiles: Home groups the account's profiles when at least two exist; this is a profile grouping/switching affordance, not a chat room.
- Page customization: section order and visibility are stored per profile for Discover, Library, Shop, and Friends & Communities. The Shop and social tabs apply those saved choices to their displayed sections.
- Messages: direct profile-to-profile conversations, with message history, unread state, replies, and reactions.
- Communities: independent memberships; a post can be associated with multiple communities through `social_post_communities`.
- Reactions/comments: persisted against social posts and messages.
- Media notes: private profile notes anchored to `media_id`, exact `media_version_id`, and playback position.
- Reviews: remain first-party media reviews and can be published/interacted with through the existing review publication system.

Important boundaries:
- Social friendship does not grant playback access.
- Social tables contain metadata/text/references only; media files remain on the home server.
- Social post photos are uploaded to the private `social-media` Supabase Storage bucket (JPEG/PNG/WebP, maximum 5 MiB). Chat attachments use the same private bucket (JPEG/PNG/WebP, MP4/WebM/QuickTime, and supported audio formats, maximum 50 MiB). The database stores an owner-scoped object path; the authenticated backend checks the owner before returning a signed URL that expires after 10 minutes (60 seconds for view-once media). This relies on private bucket access and the storage provider's at-rest protection; it is not end-to-end encryption. A recipient can still capture or retain media while it is visible.
- Apply `lib/supabase/migrations/social_media_attachments.sql` (or the mirrored `Backend/database/social_media_attachments.sql`) in addition to the Social V2 migrations before enabling photo posts.
- Apply `lib/supabase/migrations/social_chat_features.sql` (or the mirrored `Backend/database/social_chat_features.sql`) after `social_v2.sql` and `social_media_attachments.sql` before enabling richer chat, group send policies, view-once attachments, or polls.
- Apply `lib/supabase/migrations/social_chat_presence.sql` (or the mirrored `Backend/database/social_chat_presence.sql`) after `social_v2.sql`, `social_media_attachments.sql`, and `social_chat_features.sql` to enable per-member sent/delivered/read indicators, live typing status, message text formatting, and per-profile chat backgrounds.
- Direct messaging is currently restricted to accepted friends.
- Rich chat supports photo/video/voice attachments, replies, emoji reactions, emoji stickers, GIF URLs, product/media recommendation cards, friend invitations, polls in groups, per-message font/color/emphasis, per-profile chat color or image backgrounds, video sharing to multiple chats, and an admin-controlled group send policy. GIFs currently require a pasted URL; there is no built-in GIF catalog or downloaded sticker pack. Product and recommendation cards are metadata-only and do not yet deep-link into Shop or media detail pages.
- Profile identity is distinct from account membership.
- Community membership is distinct from friendship and account membership.

Apply:
- `lib/supabase/migrations/social_v2.sql`
- `Backend/database/social_v2_migration.sql`
- `lib/supabase/migrations/social_chat_presence.sql` (or `Backend/database/social_chat_presence.sql`)

The main social screen is `lib/social_center.dart`; `FriendsAndCommunitiesScreen` now delegates to it so existing navigation continues to work.
