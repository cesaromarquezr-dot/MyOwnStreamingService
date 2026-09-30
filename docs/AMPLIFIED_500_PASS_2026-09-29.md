# Amplified 500 platform pass — 2026-09-29

## What this pass establishes

The existing 500 canonical capabilities remain the ownership boundary. This pass adds the shared infrastructure and presentation contracts needed to make those capabilities behave like one connected platform.

The follow-on shared-foundation architecture is recorded in [Connected Platform Foundations](CONNECTED_PLATFORM_FOUNDATIONS.md). It formalizes universal entity identity, evidence-bearing relationships, the capability metadata registry, shared page configuration and navigation context, domain events, provider display policy, degraded operation, centralized authorization, and the reusable connection explorer. These remain shared infrastructure under existing capability owners, especially 31–48, 38, 450, and 460.

The owned-media product invariant is now explicit: external catalogs enrich works but do not populate the account library. A validated ownership/import workflow links physical items and multi-disc contents through edition/version, imported file, home server, and owned library. Ownership & Physical Media Provenance is a named cross-cutting group within the 500, mapped to existing owners rather than assigned new numbers. Existing ARM models provide release/disc/content and import-review foundations; full ownership-ledger and end-to-end library enforcement remain implementation work.

### Universal connectivity

- Shared connected-page presentation contract (`lib/connected_experience.dart`).
- Canonical graph/timeline/identity/event/search/recommendation services remain shared infrastructure.
- Cross-page navigation should route to canonical owners instead of duplicating feature logic.
- Media, social, commerce, release, X-Ray, collection, and playback contexts can be linked from the same entity.

### Franchise / saga graph

- Franchise membership is separate from continuity.
- Relationship types support direct continuity plus cameo, crossover, alternate universe, variant, reference, meta-reference, adaptation, remake, reboot, visual influence, character connection, shared creator/actor, soundtrack connection, leads-into, and related relationships.
- Relationship `continuity_effect` is independent from relationship type.
- The same model applies to Marvel, Spider-Verse, Twilight, Wizarding World/Harry Potter, Fantastic Beasts, Fast & Furious, DCEU-era material, and future franchises.

### TV Intro Library

- TV Shows page includes a dedicated `TV Intros` section when intro metadata is available.
- Intros are exact-version, offset-bound metadata rather than copied media files.
- `tv_intros` schema stores safe identifiers, offsets, season/episode context, detection method, and confidence.
- The same intro records can later power Skip Intro, intro replay, X-Ray, My TV, and playback personalization.

### External ratings

- External provider ratings remain separate records and are never silently averaged.
- Backend adapter supports TMDB and OMDb-backed provider fields when configured.
- Provider credentials are backend-only (`TMDB_API_TOKEN`, `OMDB_API_KEY`).
- IMDb's own licensed ratings/metadata program remains an option for a direct licensed integration.
- Production use must comply with each provider's terms, attribution, rate limits, and commercial licensing requirements.

## What is not falsely marked complete

This pass does not claim that every one of the 500 capabilities is fully implemented in production. Existing repository foundations remain the source of truth for implementation status. Full production work still includes durable persistence, complete cross-page wiring, external provider licensing, live media/intro detection, full commerce lifecycle, production payments, synchronization, security hardening, accessibility validation, tests, and deployment hardening.

The architectural rule is: **deepen and connect the 500; do not create 501 because a new presentation, graph relationship, provider, or page appears.**
