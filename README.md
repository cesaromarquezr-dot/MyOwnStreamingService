# netflix

A new Flutter application.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Home server / ARM architecture

The project now treats the home server as the source of truth for server-managed media. The intended physical pipeline is:

`DVD/CD/Blu-ray/UHD drive -> ARM -> completed media -> server scanner -> database/API -> Flutter`

### Backend environment

- `SERVER_HOST=0.0.0.0` — bind the API to the LAN.
- `SERVER_PUBLIC_URL=http://<server-ip>:8080` — URL clients should use.
- `ARM_SERVER_URL=http://<arm-host>:<port>` — ARM web/API address.
- `MEDIA_ROOT=/path/to/media` — root of Movies/Series/Music storage.
- `MOVIES_PATH`, `SERIES_PATH`, `MUSIC_PATH` — optional category paths.
- `MOVIES_CAPACITY_BYTES`, `SERIES_CAPACITY_BYTES`, `MUSIC_CAPACITY_BYTES`, `AVAILABLE_STORAGE_BYTES` — dashboard capacity overrides.

The current implementation does not assume a particular physical drive or UHD firmware. Verify the exact optical-drive revision and its ARM/MakeMKV compatibility before purchasing it. Audio CDs should be routed through a CD-capable ripping workflow; the server scanner already recognizes common audio output formats.

## Account, server and Group Watch architecture

- One account has one managed home server in the current subscription model.
- The server owns the account's physical Movies, TV Shows and Music files; Supabase stores metadata, identity and server indexes only.
- All profiles in an account share that account's server/library, even when profiles live in different houses.
- Remote computers can be paired as import workers. A disc/import completed at a remote house is sent over a secure connection to the account's server.
- Group Chat is cross-account: rooms are coordinated by the backend and do not require shared media storage.
- Group Watch is cross-account: each participant is associated with their own account/server, and the backend validates the requested media/version on each participant server before the session starts.
- The web client is the same Flutter application compiled for web; the server-side agent/API is deployed separately on each physical media server.

## Managed-server subscription pricing

The backend calculates the public price from configurable server hardware/storage amortization, estimated electricity, bandwidth/operations, support reserve, payment processing and target gross margin. The default retail price is **$54.99 USD/month** or **$599.99 USD/year** for one managed server. Operators can change the assumptions with environment variables; the client never controls the amount charged.

## Canonical roadmap and architecture

The project now uses a consolidated architecture model for the larger roadmap. The historical roadmap contains 1,000 requirements, while the canonical implementation catalog contains 500 capabilities with one owner per capability. Contexts such as Stories, Live Shopping, Watch Party, Marketplace, Movies, TV and Music extend shared systems instead of creating duplicate implementations. The roadmap's breadth is set; the next phase deepens integration, intelligence, reliability, privacy, accessibility, and polish.

See [`docs/CANONICAL_ARCHITECTURE.md`](docs/CANONICAL_ARCHITECTURE.md) for the canonical shared capability architecture, Universal Media Actions, integration ownership, and delivery order.

See [`docs/MASTER_CAPABILITY_ROADMAP.md`](docs/MASTER_CAPABILITY_ROADMAP.md) for the carried-forward Phase 1/2 foundation, the numbered Phase 3 additions through #116, and the separate productionization track.

The feature map for media versions, universal profile actions, dynamic collections, and relationship graph ownership is included in the canonical architecture document.

See [`docs/XRAY_ARCHITECTURE.md`](docs/XRAY_ARCHITECTURE.md) for the canonical X-Ray capability, its version-specific timeline and spoiler model, and the implementation path from the current player overlay.

## Consolidated product features

This snapshot includes consolidated food-delivery messaging, restaurant review/profile/theme support, disc-import episode-order safeguards, and app/media localization work. Gaming has been removed from the project's feature scope. Review [`docs/FEATURE_CONSOLIDATION_STATUS.md`](docs/FEATURE_CONSOLIDATION_STATUS.md) for included behavior, the required SQL migration order, integration dependencies, and known validation limits.

For an auditable list of every created, modified, and deleted file in this consolidated snapshot, see [`docs/CHANGE_MANIFEST.md`](docs/CHANGE_MANIFEST.md). The manifest compares against the available source archive and cannot include unuploaded edits in a separate local working copy.

## Hey Marathon

Open **More → Hey Marathon** to create a timed movie or TV marathon from the current profile's library. The planner expands series into numbered episodes, protects against saving unresolved episode order, schedules breaks, lets users share invitations, and passes the theme into Hey Eats. Plans are stored locally per profile on the current device. See [HEY_MARATHON.md](HEY_MARATHON.md) for behavior and verification steps.

## Expanded platform capabilities

The next set of additions (proactive Hey Media suggestions, custom media spaces, franchise viewing orders, metadata provenance, NAS health, integrations, and recovery foundations) is documented in [`docs/EXPANDED_PLATFORM_PHASE2.md`](docs/EXPANDED_PLATFORM_PHASE2.md). Its additive migration is `Backend/database/expanded_platform_phase2.sql`. These are foundations and roadmap entries, not a claim that all integrations are complete.

The next-wave shared foundation is documented in [`docs/EXPANDED_PLATFORM_IMPLEMENTATION.md`](docs/EXPANDED_PLATFORM_IMPLEMENTATION.md). It includes typed Flutter capability metadata and an additive Supabase migration in `Backend/database/expanded_platform_features.sql`. Podcasts and audiobooks are intentionally excluded from the product scope.

The general product foundations added in Phase 3 are documented in [`docs/PLATFORM_FOUNDATIONS_ARCHITECTURE.md`](docs/PLATFORM_FOUNDATIONS_ARCHITECTURE.md), with owner-scoped collector-edition and recommendation-feedback tables in `Backend/database/expanded_platform_phase3.sql`. This adds source-level foundations and contracts; it does not mean the full gateway, AI orchestration, payments, or NAS health workers are complete.

## Streaming experience quality foundation

The project includes profile-scoped playback preferences, device-local QoE diagnostics, typo-tolerant universal media search, an adaptive playback view for trusted signed HLS/DASH or progressive URLs, a sample HLS VOD ladder script, and a service-role-only Supabase schema for future trusted telemetry ingestion. See [Streaming Experience Implementation](docs/STREAMING_EXPERIENCE_IMPLEMENTATION.md) for setup, limits, security rules, and the remaining media-gateway integration required for true end-to-end TrueNAS streaming.

## Production readiness, privacy, and recovery

See [`docs/PRODUCTION_READINESS_AND_RELIABILITY.md`](docs/PRODUCTION_READINESS_AND_RELIABILITY.md) for the rollout steps covering privacy-aware presence/diagnostics, owner-gated operations probes, accessibility, offline progress sync, Hey Media action confirmation, CI quality gates, encrypted database backups, and TrueNAS recovery boundaries. Use [`docs/RECOVERY_DRILL_CHECKLIST.md`](docs/RECOVERY_DRILL_CHECKLIST.md) for scheduled restoration drills. Apply `Backend/database/production_readiness_and_privacy.sql` only after a verified backup and the existing base/account migrations.

## Entertainment Studio and upgraded My TV / storage tools

The Home page and More menu include Entertainment Studio: profile-scoped calendar and journal records, scene bookmarks, collector-edition notes, household watchlist votes, subtitle correction drafts, fan theories, safe layout-preset JSON export/import, Cinema Room preference presets, recommendation feedback, catalog metadata audits, and a metadata-derived Movie Knowledge Graph. Records are stored locally first; optional authenticated Supabase sync for Studio records requires `Backend/database/entertainment_studio_records.sql` (also mirrored in `lib/supabase/migrations/`). Sharing with other signed-in accounts requires a separate membership/ACL design.

My TV has quick-create channel templates that reuse the existing profile-aware guide and eligibility filtering. The Server Storage dashboard now reads actual authenticated server category/filesystem data instead of hard-coded zero values; host-level SMART/ZFS/UPS/CPU/temperature and transcoder monitoring still requires a privileged server-side collector. See `docs/ENTERTAINMENT_STUDIO_EXPANSION.md` for scope and deployment limits.
