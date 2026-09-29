# X-Ray: contextual media intelligence

X-Ray is one canonical capability owned by **Playback & Media Experience** and **Media Identity / Metadata**. It presents time-aware context for the exact media version being played and links that context into the existing media graph and profile systems. Its scope is not limited to cast credits.

## Identity and ownership

```text
Canonical Work
└── Media Version / Edition
    ├── Home server: the actual media file and playback timeline
    └── Supabase: version-specific X-Ray timeline and contextual metadata
```

The canonical work identifies the creative title. A media version identifies a particular cut, edition, runtime, and timeline (for example, theatrical versus Encore). X-Ray events belong to a version; they must not be copied onto the canonical work as if timestamps were interchangeable. Each event references canonical people, characters, locations, music, and media graph entities where available. Server files and stream URLs remain server-owned.

Events use offsets in the selected version's playback timeline, with a start and optional end. The player position selects the active event; gaps are valid and should not fabricate a scene. Imported legacy records may omit a version identifier, but new authoritative timelines should always declare one. Metadata provenance and confidence should be retained so curated facts remain distinguishable from inferred enrichment.

Example event shape:

```yaml
mediaVersionId: endgame-encore
startSeconds: 252
endSeconds: 395
eventType: scene
title: Tony Stark and Steve Rogers
characters: [tony-stark, steve-rogers]
people: [robert-downey-jr, chris-evans]
location: avengers-compound
music: []
spoilerScope: current_scene
source: curated
```

## Context and navigation

X-Ray can show the active scene, people and characters, biographies, character relationships and appearance history, music and track actions, locations, props, trivia, behind-the-scenes notes, and related media. Relationship cards explain their graph edge (such as sequel, prequel, actor, character, story, post-credit, or multiverse connection) and navigate to the existing title/person/character destinations.

People and fictional characters are separate entities and profiles. A cast credit connects an actor to a character for a work/version; it does not collapse their biographies or filmographies. Character appearance history and first/last appearance are graph-derived and subject to spoiler rules.

The user's library state, likes, collections, playlists, and wishlist are profile/application state, not global X-Ray metadata. X-Ray reads and acts on the existing universal systems rather than creating X-Ray-specific copies. Music actions similarly route through Universal Likes and Playlists and existing track/artist/album identities.

## Spoiler protection

The active profile chooses one of five spoiler levels: **No spoilers**, **Current scene**, **Current movie**, **Franchise**, or **Everything**. The effective policy is the stricter of the user's selection and the information's spoiler scope. Current-scene context is available only when allowed; future appearances, outcomes, and character timelines require broader levels. The setting applies consistently to related media, character history, trivia, and profile navigation previews.

## Presentation

The capability supports compact overlay, side panel, and full-screen presentation. Player preferences choose a presentation independently from spoiler protection. All presentations consume the same event/context contract and retain playback position when opened or dismissed.

Profiles can personalize visible X-Ray sections and follow actors, characters, directors, composers, or franchises. Follow state belongs to the profile and can feed release notifications only through the shared notification preferences and release graph. Library appearance lists are derived from that profile's existing library and canonical credits; X-Ray does not maintain a second filmography database.

Private notes and shared references include the canonical media ID, exact media-version ID, and playback offset. A note is private profile data and must never be included in a shared metadata cache. An exact share action is unavailable when the selected media version is unknown. Shared references resolve only after the recipient's access to that media is checked.

User-selected X-Ray sections include people, characters, music, locations, trivia, props, behind-the-scenes, production, and connections. Accessibility settings are inherited from the player/app accessibility capability. Offline playback can cache the X-Ray metadata manifest alongside the selected version's video/audio/subtitle assets; the manifest remains metadata and does not contain or relocate the media file.

## Capability inventory

- Scene awareness and version-specific event timelines
- Actors and characters as distinct graph entities
- Biographies, filmographies, character appearances, and relationships
- Music, locations, props/vehicles/costumes, trivia, and behind-the-scenes context
- Explained related-media graph links
- Version awareness and profile-scoped spoiler protection
- Library status, likes, playlists/collections, wishlist, and contextual navigation
- Compact overlay, side panel, and full-screen presentation
- Curated, version-specific metadata as the authoritative layer; AI inference is optional enrichment

## Current implementation and next steps

The Flutter player currently opens `lib/xray.dart`, follows `MediaItem.xrayEvents` as playback advances, filters events by `mediaVersionId`, and offers spoiler-level and visible-section controls. Followed cast entities, section choices, and private notes are currently stored in profile-keyed device preferences. Library appearances are derived from current library credits. The backend defines typed version-bound X-Ray events and private notes, but those models are not yet connected to profile-synced persistence, notifications, or share-link routing. Legacy client event payloads remain untyped maps and render if they lack a version ID.

The canonical architecture extension already has media editions, media versions, and a general `media_timeline_events` table. That table currently represents dated media events; it is not yet the playback-offset X-Ray timeline contract. Do not overload it without a migration that separates event date from playback offsets and defines version ownership.

Recommended implementation sequence:

1. Connect typed version-bound events to Supabase/API persistence and offline cache manifests, preserving compatibility with existing `xrayEvents` payloads.
2. Persist spoiler and section preferences with the profile and apply spoiler policy at metadata query/presentation boundaries.
3. Model actor, character, and cast-credit links separately; connect follows to canonical graph IDs and shared release notifications.
4. Persist private notes as profile-owned records and implement access-checked deep links for exact version/timestamp references.
5. Route related titles, library state, likes, playlists/collections, and wishlist through their existing services.
6. Add production credits, fictional/filming location distinction, appearance timelines, accessibility polish, and remaining event curation/import workflows.

Live AI vision is not required for correctness. Curated version-specific timestamps remain authoritative; inferred candidates can be reviewed, sourced, and cached as enrichment.
