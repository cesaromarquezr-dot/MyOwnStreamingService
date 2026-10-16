# Expanded Platform Implementation

## Scope

This expansion adds the shared foundation for the next wave of MyOwnStreamingService features: Hey Media agent capabilities, searchable scene metadata and bookmarks, personal entertainment timelines, collections, wishlists, privacy and accessibility preferences, device registrations, clubs/events, creator workspaces, notification preferences, library-health findings, feature flags, audit events, and durable background-job records.

**Podcasts and audiobooks are intentionally out of scope.** Do not add navigation, database entities, catalog types, import flows, recommendation categories, or player modes for either format.

## New files

- `lib/expanded_platform.dart`: typed capability catalog, bookmark and assistant-memory models, and a Supabase repository for scene bookmarks and explicitly user-managed Hey Media memory.
- `Backend/database/expanded_platform_features.sql`: additive Supabase schema with ownership-oriented row-level security for personal data.
- `test/expanded_platform_test.dart`: catalog and bookmark model tests.

## Apply the migration

1. Back up the Supabase database.
2. Review `Backend/database/expanded_platform_features.sql` against your deployed schema and current RLS conventions.
3. Apply it through the Supabase SQL Editor or your migration workflow.
4. Verify the RLS policies with separate authenticated test users before enabling UI flows.
5. Keep `service_role` credentials only on trusted backend workers. Never put them in Flutter build arguments, app configuration, or the TrueNAS client.

The migration is additive and uses separate table names to avoid changing existing tables. Scene-search indexing, background jobs, feature flags, and audit events are intentionally not writable by ordinary authenticated clients. A trusted backend route/worker must own those operations.

## Security notes

- Personal tables default ownership to `auth.uid()` and enforce owner-scoped RLS.
- AI memory is explicit, editable, and deletable; do not store passwords, tokens, payment credentials, or sensitive inferred attributes.
- Scene-search results must be filtered by media-access rights on the server before returning any result or playback URL.
- `media_key` is a stable app-level reference, not a filesystem path or authorization token.
- Device registration records are informational. They do not by themselves revoke Supabase sessions; connect them to a server-side session/device authorization design before treating them as a security boundary.
- Creator workspace membership is a starter collaboration model. Before public launch, add invitation flows, ownership-transfer rules, abuse reporting, retention policies, and more granular RLS tests.
- Public/friends visibility values are metadata only in this migration. Do not expose another user's records until read policies implement and verify those visibility rules.
- Feature flags and rollout decisions must be evaluated server-side for sensitive capabilities. Client-side flags are presentation controls, not authorization.

## Implementation stages

1. **Foundation**: apply and test schema, add integration tests for RLS, wire preferences and bookmark UI, and implement job workers.
2. **Discovery**: index authorized captions, chapters, transcripts, and optional scene descriptions; add server-side search and media-permission filtering.
3. **Social**: implement club discovery, invites, moderation, spoiler rules, event RSVP, and community review flows.
4. **Commerce**: connect wishlists, restock/price alert providers, receipts, refunds, and seller/restaurant operations to existing commerce APIs.
5. **Creators and devices**: implement collaboration invites, publishing workflows, registered-device revocation, and supported device adapters.
6. **Operations**: add feature-flag administration, job retries/dead-letter handling, audit retention, metrics, backup verification, and end-to-end tests.

## Verification status

The archive contains the additive source and tests, but this does not mean every feature is production-complete. Database migration execution, Supabase RLS integration tests, device/provider credentials, background workers, and UI wiring must be completed and verified in the target environment. Run `flutter analyze`, `flutter test`, and the backend analyzer after applying the changes.
