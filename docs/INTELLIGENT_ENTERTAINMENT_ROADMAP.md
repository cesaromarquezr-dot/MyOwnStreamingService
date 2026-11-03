# Intelligent Entertainment Roadmap

## Product direction

Build an entertainment companion that helps each profile decide what to do,
understand its library, remember what it experienced, and control its own
experience. Add capabilities to the existing media, experience, intelligence,
and identity domains; do not create a parallel catalog or duplicate profile
settings.

The roadmap is a product plan, not a claim that every described capability is
already complete. Existing screens and local persistence are foundations until
their behavior is verified end to end.

## Architecture and shared contracts

- **Catalog identity:** `MediaItem.id` identifies a library/catalog record;
  `canonicalWorkId` groups editions of the same work. Use typed entity IDs for
  people, works, editions, episodes, albums, and songs. Never merge by title
  similarity alone.
- **Activity:** Use a profile-scoped, timestamped event contract for playback,
  completion, and discovery. Keep event capture independent of calendar,
  Wrapped, goals, My Firsts, and Concierge so those features share one source
  rather than maintaining separate histories. Store IDs and permitted metadata,
  never media bytes, credentials, or raw storage paths.
- **Relationships:** Extend the provenance-aware media graph for cross-domain
  links. Preserve relationship type, evidence, source, confidence, and
  verification; do not treat inferred links as verified facts.
- **Profile preferences:** Keep personalization, privacy, warnings,
  notification schedules, goals, and favorites profile-scoped. Preserve
  existing stores and APIs as canonical owners; expose them through a unified
  studio instead of copying their settings.
- **Intelligence:** Concierge and recommendations may rank eligible catalog
  records, but must honor profile policy, library availability, user intent,
  and explicit metadata. Make reasons and uncertainty visible; do not let an
  AI response authorize playback or bypass safety.
- **Reliability:** Treat user-authored data as distinct from provider metadata.
  Refreshes must not overwrite user locks, custom relationships, ratings,
  collections, timelines, or profile preferences. Use validated migrations,
  versioned backups, conflict-aware sync, and explicit recovery errors.
- **Localization:** Format dates, numbers, times, regional releases, and age
  ratings through locale/region-aware contracts. Preserve original release
  dates separately from regional release dates. RTL support is a layout and
  interaction requirement, not just translated strings.

## Existing foundations to reuse

These are partial implementations, not end-to-end completion claims:

- `entertainment_extensions.dart` stores a bounded, profile-scoped completion
  journal used by Wrapped; it currently records completions, not every start,
  pause, or partial play.
- `details.dart` selects editions explicitly linked by canonical work ID.
- `media_graph_relationship.dart` stores provenance-aware work-to-work edges.
- `profile_content_safety.dart` and profile governance provide age and safety
  controls; custom advisory taxonomies and warning behavior still need a
  verified metadata source and policy model.
- `localization.dart` provides application-language selection; regional dates,
  age-rating systems, metadata sources, and complete RTL behavior remain
  separate work.
- `automatic_backup_service.dart` backs up local preferences; it does not
  replace server/database backups or synchronize account data.
- Existing profile customization, privacy, notifications, playlists, music
  likes, and media likes should be consolidated at their current canonical
  owners, not forked.

## Prioritized implementation phases

### Phase 0 — Protect the foundation

1. Define and test the shared profile activity contract, privacy/retention
   behavior, and migration/backfill strategy.
2. Verify backup restore, metadata protection, sync conflict handling, and
   graceful read-only behavior against the actual persistence paths.
3. Add diagnostics that identify dependency failures without exposing secrets
   or private media paths.

**Exit criteria:** profile isolation and access policies are tested; a failed
write is visible and retryable; restore and migration failures preserve the
previous valid state.

### Phase 1 — Personal intelligence and memory

1. Watch History Calendar, initially backed by the existing completion journal.
2. My Firsts and personal goals, derived from the shared activity contract.
3. Entertainment Concierge, with intent-specific plans across eligible movies,
   episodes, and music; plans remain editable and temporary until saved.
4. Universal Favorites, using typed entity references and existing per-domain
   state migration rather than title strings.

**Exit criteria:** features are profile-scoped, explain data gaps, never infer
completion from a partial play, and can be disabled or cleared without
destroying unrelated settings.

### Phase 2 — Trustworthy content knowledge

1. Add personalized advisories with source and verification state; keep them
   independent from age ratings.
2. Extend content relationships to books, people, locations, soundtracks,
   historical events, episodes, and other supported entity types.
3. Improve movie and album edition matching using canonical IDs and reviewable
   suggestions. Keep distinct editions selectable and never auto-merge records.

**Exit criteria:** uncertain metadata is labeled, users can correct or protect
their data, and relationship/edition changes preserve playback and ownership
identity.

### Phase 3 — Profile control and regional polish

1. Personalization Studio as a navigation layer over existing profile-owned
   appearance, Home, playback, discovery, language, privacy, and notification
   settings.
2. Notification priorities, quiet hours, digest summaries, and per-profile
   delivery controls.
3. Regional formats, release dates, ratings, metadata language/source
   preferences, holiday calendars, and right-to-left layout support.

**Exit criteria:** settings have a single source of truth, respect OS reduced
motion/accessibility settings, and behave correctly after a profile or locale
change.

### Continuous product quality

Apply the shared visual and interaction language throughout each phase: useful
loading and empty states, actionable errors, consistent cross-media layouts,
subtle transitions, and no animation that defeats accessibility or performance.
Validate each vertical slice with focused tests, app analysis, and a live
device smoke test before expanding its scope.

## Feature inventory and acceptance boundaries

| Feature | Priority | Primary dependency | Minimum trustworthy behavior |
|---|---|---|---|
| Entertainment Concierge | Phase 1 | Activity, catalog eligibility, intent filters | Explain picks, respect time and profile policy, distinguish unknown metadata |
| Watch History Calendar | Phase 1 | Profile activity events | Local-date calendar, day details, media filters, honest completion-only boundary |
| My Firsts | Phase 1 | Activity plus verified country/artist/genre/people metadata | No “first” claim when prior history or metadata is incomplete |
| Cross-media relationships | Phase 2 | Typed catalog entities and provenance | Navigable links with source, confidence, and verification state |
| Personalized content warnings | Phase 2 | Advisory metadata and profile preferences | Separate from age ratings; support warning/filter/hide choices and source status |
| Intelligent edition matching | Phase 2 | Canonical work and edition identity | Suggest, review, and select; never merge based on title alone |
| Respectful notifications | Phase 3 | Notification center and profile preferences | Priority, quiet hours, digest, and urgent system exceptions |
| Personal goals | Phase 1 | Reliable activity metrics | Editable, private progress; no competitive defaults |
| Universal favorites | Phase 1 | Typed entity IDs and legacy migration | Cross-media list with stable identity and removable favorites |
| Personalization Studio | Phase 3 | Existing settings owners | One profile hub; no duplicate preference stores |
| Localization and regional experience | Phase 3 | Locale/region metadata contracts | Localized formats and ratings while preserving original release data |
| Reliability and data protection | Phase 0 + continuous | Persistence, backup, migration, sync | Recoverable updates and protection for user-authored information |

## Large-library experience roadmap

This sequence organizes the newer library, playback, automation, and
integration proposals around the existing catalog, player, storage, metadata,
profile, and recommendation owners. These are additions to the product plan,
not claims that the capabilities are already implemented end to end.

### Scope and product guardrails

- Keep all features optional, discoverable, profile-aware, and configurable.
  Add contextual entry points and progressive disclosure rather than forcing
  advanced workflows into basic browsing or playback.
- Preserve the owned-library rule: metadata search, external catalogs, and
  integrations do not create owned or playable media records.
- Preserve existing removals and exclusions. Gaming remains removed, and
  podcasts and audiobooks remain outside the product scope.
- Storage inspection is advisory and read-only. Never automatically delete,
  move, merge, or transcode a user's media.
- Treat user-authored metadata, bookmarks, vocabulary, automation rules, and
  preferences as private data with explicit export, retention, and deletion
  behavior.

### Phase 0 — Shared contracts and reliability

1. Reuse stable media, episode, album, and exact media-version IDs. Bind
   timestamps, chapters, subtitle matches, and playback seeks to the relevant
   version rather than title text or a presumed universal runtime.
2. Define source, confidence, verification, freshness, and user-protection
   semantics for metadata. Extend the existing provenance/field-protection
   implementation; do not create a second metadata store.
3. Inventory the subtitle formats, authorized sources, player seek/track
   support, server storage measurements, and profile progress already
   available. Represent unavailable or unknown measurements honestly.
4. Define an allowlisted automation trigger/action contract and a permission
   model for integrations before enabling background execution or storing
   connection credentials.
5. Test profile isolation, migration and restore, large-library performance,
   accessible controls, surfaced errors, and disabled-feature behavior.

**Exit gate:** each feature has a mapped canonical owner, data lifecycle,
permission boundary, failure behavior, and measurable acceptance criteria.
Existing local, server, and provider data remain distinguishable.

### Phase 1 — Searchable, trustworthy library

1. **Content provenance and confidence:** extend existing field-level
   provenance to show whether information is user-created, provider-sourced,
   server-sourced, assistant-generated, community-submitted, or manually
   verified. Show confidence and last-updated time when actually available.
   Preserve protected fields and label missing provenance as unknown rather
   than inventing a source.
2. **Media Storage Intelligence:** build on the existing authenticated
   storage dashboard. Show measured category usage, largest files, duplicate
   edition candidates, missing paths, growth history, estimated capacity, and
   quality-versus-size details only where source data supports them. Separate
   host capacity from configured media-category totals; never imply SMART,
   ZFS, or other host-health coverage unless a trusted monitor supplies it.
   Provide review/export suggestions, not destructive cleanup actions.
3. **Search Inside Movies & Shows:** index authorized subtitle files and
   transcripts as searchable text associated with a media/version ID. Return
   title, season/episode, timestamp, and a short dialogue snippet. Search
   results can seek only when the selected player supports it; otherwise show
   the timestamp without promising a jump. Report missing, stale, or
   unsupported indexes explicitly. The initial vertical slice supports
   authenticated `.srt`/`.vtt` sidecars on the home server, a bounded
   in-memory index, profile-filtered results, and seeks for playable server
   media; embedded tracks, persistent indexes, and transcripts remain future
   work.

**Exit gate:** users can inspect a result's source and freshness, storage
measurements show their scope and unknowns, subtitle results identify the
correct episode/version, and no library file is changed by indexing or
analysis.

### Phase 2 — Playback understanding and learning

1. **Episode Catch-Up Assistant:** generate short, medium, or detailed
   recaps from episodes confirmed as watched, plus explicitly permitted
   earlier context. Respect the selected profile's progress and spoiler
   settings; never use later or unwatched episodes. Label incomplete progress
   or unavailable recap sources, and do not present unsupported generated
   details as fact.
2. **Interactive chapters:** support version-bound chapter markers for
   introductions, story segments, performances, character introductions,
   and post-credit scenes. Let users create private bookmarks and review
   suggested/imported markers. Validate timestamps against runtime; make
   export and sharing explicit and privacy-controlled.
3. **Language and subtitle learning:** display synchronized original dialogue
   and selected translations when both tracks exist, save words to
   profile-private lists, replay supported dialogue segments, and search
   indexed subtitles. Keep translations attributed to their source and do not
   imply that every subtitle track is aligned or accurate.
4. **Personal Theater:** add opt-in ambient artwork, configurable countdowns,
   optional trailers selected only from the user's available library,
   intermission reminders, end-credit behavior, post-movie information, and
   a chosen continuation order. Every step can be disabled or skipped; do not
   auto-play unavailable or unauthorized content.

**Exit gate:** recaps pass spoiler-boundary tests; chapters seek against the
correct version and remain editable; language tools disclose missing track
support; and theater flows are skippable, profile-scoped, and do not alter
playback or queue state unexpectedly.

### Phase 3 — Personal automation and contextual experiences

1. **Personal Automation Studio:** let users create, edit, disable, and
   inspect rules using an allowlisted set of events and actions, such as a
   new-episode notification or metadata check after an album import. Show
   recent runs, errors, and retry status. Require idempotent handling and
   explicit consent for each rule; exclude silent acquisition, deletion, or
   other destructive actions.
2. **Recommendations by situation:** accept intent such as available time,
   family viewing, a complete story, nostalgia, background music, or discovery.
   Rank only eligible library items using explicit runtime, profile policy,
   availability, preferences, and history where permitted. Explain matches,
   distinguish unknown data, and let users refine or dismiss suggestions.
3. **Application integrations and extensions:** introduce a modular
   capability registry for metadata, music identification, lyrics,
   subtitles, calendars, notifications, backups, and home automation.
   Present each connector's status, requested permissions, data use, and
   disconnect/revoke controls. Start with explicit supported adapters rather
   than arbitrary plugin execution; keep secrets out of the Flutter client.
4. **Context-aware interface:** offer relevant, optional modules for the
   selected entity and current activity—for example, a movie's soundtrack,
   story connections, cast, editions, and collections, or an artist's
   discography, collaborations, soundtrack work, and listening statistics.
   Keep modules dismissible and preferences-controlled, and route actions to
   their existing canonical owners.

**Exit gate:** automations are auditable and reversible, integrations can be
disconnected without corrupting local data, recommendations explain their
constraints, and contextual modules do not overwhelm or replace the basic
media experience.

### Cross-feature acceptance checklist

- All new indexes, recaps, bookmarks, automation rules, and learning data
  follow profile ownership, privacy, backup, and deletion rules.
- Large-library operations are bounded, cancellable, and recoverable; work
  does not block ordinary browsing or playback.
- Provider, assistant, community, and server data retain distinct provenance.
  Suggestions never overwrite protected user-authored metadata.
- A feature is marked complete only after focused tests, app analysis, and a
  representative device/server smoke test pass. Unsupported platform or
  provider behavior remains documented as a limitation.
