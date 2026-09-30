# Canonical platform architecture: shared media capabilities

The platform should deepen its shared systems instead of creating a separate implementation for every media type or experience. Movies, shows, episodes, tracks, albums, products, and future content types use canonical identity and expose the actions their capabilities allow.

## Owned-media product invariant

The core library contains only media the account has acquired and imported/ripped from physical media it owns. External catalogs and providers can enrich known works with metadata, artwork, ratings, releases, cast, and relationship information, but cannot create owned library records. Searching for a title, opening its metadata, following a relationship, or buying a marketplace listing is not library membership. The Store is an acquisition surface, not a parallel streaming catalog. Library membership is established by a validated ownership/import event and server registration; discovery remains separate and can be entered explicitly.

Current ownership, prior ownership, physical possession, imported server copies, and playback availability are separate facts. Transitions such as Sold or Lost preserve history and provenance. A user may retain the historical library record after disposition, labeled as previously owned, without representing the item as currently owned.

## Capability count and shared infrastructure

The product model is **1,000 original requirements distilled into 500 canonical capabilities**. The numbered capability inventory is the source of truth for ownership and planning. A graph, timeline, event bus, search service, recommendation service, or UI surface is shared infrastructure that enables those capabilities; it is not another capability number. A new presentation mode or a smarter relationship/timeline view therefore does not increase the count.

The 500 owners are grouped in these established ranges: 1–15 Identity, Accounts & Profiles; 16–30 Authentication & Security; 31–48 Media Identity & Metadata; 49–68 Movies & Television; 69–88 Music; 89–101 Home Servers & Media Storage; 102–115 Playback & Media Experience; 116–128 Collections & Library Organization; 129–142 Search & Discovery; 143–155 Recommendations & Personalization; 156–169 Releases & Availability; 170–181 My TV; 182–193 Home Experience; 194–204 Social Graph; 205–220 Messaging & Communication; 221–234 Watch Party / Group Watch; 235–247 Media Social Interaction; 248–262 Stories; 263–281 Marketplace; 282–296 Commerce Transactions; 297–306 Reviews & Reputation; 307–323 Stores & Sellers; 324–331 Seller Analytics; 332–341 Shipping & Fulfillment; 342–352 Loyalty, Rewards & Promotions; 353–367 Collaboration & Creator Commerce; 368–387 Live Shopping; 388–394 Randomized Live Rewards; 395–405 Notifications; 406–417 Activity & Analytics; 418–430 Community; 431–442 Moderation & Safety; 443–449 Communication Preferences; 450–465 Infrastructure Services; 466–476 Backend & Synchronization; 477–486 Backup, Recovery & Reliability; 487–494 Localization & Regionalization; and 495–500 Accessibility.

Use this ownership rule when planning work:

1. Map a requirement to an existing numbered capability owner.
2. Reuse shared graph, timeline, identity, event, search, notification, synchronization, and policy services where they fit.
3. Add a capability only when the user-facing responsibility has no existing owner in 1–500. A new graph domain, timeline view, player presentation, or integration is not sufficient reason on its own.

## Identity, graph, and time model

The graph describes **relationships**. Timelines describe **when**. Capabilities describe **what a user can do**. UI surfaces present the result. Shared graph and timeline services amplify the canonical owners; they do not compete with them.

The media identity chain is:

```text
Franchise / Universe
  → Canonical Work
    → Media Version
      → Physical or Digital Edition
        → Release Event
          → Account Physical Item / Disc(s) → Disc Content → Import/Rip
            → Actual Server Media → Owned Library Media
            → Playback Session and Version-Bound Timeline
```

Each layer has its own stable identity and meaning. An edition or release does not become a new canonical work merely because its title or release date differs. A file is an availability/storage record, not the canonical work. Playback offsets, scene boundaries, and X-Ray events bind to the exact media version because cuts can have different runtimes and timelines.

### Shared graph infrastructure

The graph is a common typed relationship engine with provenance, confidence, direction, and source where applicable. Domain views can include media, franchise, character, people, story, version, release, scene, X-Ray, collection, social, commerce, and live-shopping relationships. These are graph domains over shared infrastructure, not independent relationship engines.

Edges are explicit and typed, for example `sequel_to`, `prequel_to`, `spin_off_of`, `alternate_version_of`, `character_connection`, `adaptation_of`, `references`, and `leads_into`. Relationship edges can explain navigation and recommendations, but do not silently determine user collection ordering. A user-created collection such as “Marvel Cinematic Multiverse” is a user taxonomy, not a global canonical assertion that every included work shares one objective continuity.

### Shared timeline infrastructure

One timeline service supports different temporal data through typed records and adapters. Examples include release, story chronology, franchise branch, character appearance, actor career, media-version, episode, scene, X-Ray, watch/listening, collection, social activity, order, shipment, livestream, and reward timelines. They are uses of shared temporal infrastructure, not separate timeline engines or new numbered capabilities.

Keep time semantics explicit: a release date is not a playback offset; story order is not release order; and a scene/X-Ray offset belongs to one exact media version. X-Ray is a time-aware consumer of playback and media identity capabilities (principally 31–48, 67, and 102–115), with its contextual entities resolved through the graph. Amazon-style menus, Netflix-style side panels, and Disney+-style navigation are presentation choices of playback capability 109, not separate audio systems.

## Capability ownership examples

| Experience or concept | Canonical owners it amplifies |
|---|---|
| Ownership & Physical Media Provenance (cross-cutting group within the 500) | 31–48 identity/version/provenance; 89–101 physical items, discs, import, server files and integrity; 116–128 owned library and collections; 156–169 release/availability; 282–296 and 332–341 acquisition evidence; 477–486 backup/recovery |
| X-Ray and scene-aware context | 31–48, 67, 102–115 |
| Actor and character cards/timelines | 36–40, 67, 132–133 |
| Franchise graph and chronology | 37–40, 66, 134 |
| Media-version timeline and Encore editions | 33, 39, 62–64, 158–162 |
| Release countdowns and personalized release awareness | 156–169, 395–405 |
| X-Ray likes, collections, recommendations, chat, and accessibility | 9, 116–128, 143–155, 205–247, 495–500 |
| Seller payout methods | 282–296, 307–323 |
| Marketplace discovery, product pages, and comparison | 263–281 |
| Buyer cart, checkout, order lifecycle, and protection | 282–296 |
| Product/store reviews and seller reputation | 297–306, 307–323 |
| Seller dashboard and performance reporting | 307–331 |
| Shipping, delivery, and fulfillment | 332–341 |
| Loyalty, coupons, credit, and promotions | 342–352 |
| Seller/creator collaboration and revenue sharing | 353–367 |
| Live shopping and optional randomized rewards | 368–394 |
| Category-filtered likes and dynamic playlists/collections | 9, 70, 116–128, 452 |
| Media-aware Stories and randomized live rewards | 248–262, 368–394 |

Commerce remains a single connected buyer/seller ecosystem. The marketplace owns discovery and product identity; transaction capabilities own buyer payment, checkout, and orders; seller capabilities own stores, payout destinations, and seller business state. Seller payout destinations are never buyer checkout methods. Analytics, fulfillment, promotions, collaboration, live shopping, and rewards extend their listed owners and reuse shared identity, notification, audit, and policy services.

## Shared page presentation and Storefront Designer

`PagePresentation` in `lib/page_presentation.dart` is the reusable visual-token layer for customizable pages. A page-specific configuration can add content/layout settings while inheriting the shared theme mode, brand palette, background, typography scale, and control radii. `StorefrontDesign` is the first specialized configuration and is serialized with its canonical `ShopStore`; the public Store renderer consumes it. This keeps theme rendering and design tokens reusable instead of creating a separate design system for each page.

The Storefront Designer owns storefront presentation under capabilities 307–323. It configures theme presets/custom colors, light/dark/device appearance, solid/gradient/image backgrounds, hero text and image positioning/overlay, mobile hero imagery, font family/scale, control and card radii, product list/grid and responsive columns, image ratio, and the order of currently implemented storefront sections. Product, cart, checkout, order, payout, shipping, review, loyalty, analytics, and live-shopping behavior remain owned by their existing commerce capabilities. Presentation settings cannot change transaction rules or bypass product/store permissions.

The current editor/rendering pass supports static images, not video/animated backgrounds or rotating multi-banner campaigns. Per-section background editing, social-link presentation, review/story/event/collection modules, and persistence through a multi-device backend storefront record remain follow-up work. The designer exposes no unsupported section as if it were implemented.

For example, “Avengers: Endgame” remains one canonical work. “Theatrical 2019” and “Encore 2026” are versions; Blu-ray and 4K UHD are editions/releases; and the physical disc and server file are separate availability records. A story relationship such as `leads_into → Doomsday` can coexist with a user collection that independently chooses its own ordering.

## Universal Media Actions

**Universal Media Actions** is the single shared interaction layer between content surfaces and domain services. A card, search result, X-Ray entity, or detail page asks the action layer which actions apply to a canonical object and profile, then invokes the existing owner for that action.

```text
Content surface
      ↓
Universal Media Actions
      ├── Capability and permission check
      ├── Shared action presentation
      ├── Pending / success / error result
      └── Domain service adapters
            ├── Playback and download → home server / playback
            ├── Like and rating → universal profile media state
            ├── Playlist and collection → universal collection service
            ├── Note and review → profile content services
            ├── Wishlist and purchase → existing commerce services
            └── Share → access-checked media references
```

The action set is contextual: **Play, Like, Add to Playlist, Add to Collection, Add Note, Rate, Review, Share, Download, Queue, Wishlist, More**. Unsupported actions are omitted or disabled with a clear reason. The layer does not own duplicate likes, playlists, reviews, or commerce records. It routes to the canonical service and presents a consistent result. Actions carry profile identity, canonical object identity, optional exact media-version identity, and an idempotency key so retries and offline sync do not duplicate work.

## Canonical capability owners

| Capability | Canonical owner | Shared behavior |
|---|---|---|
| Universal activity center and personal media timeline | Activity and profile privacy | One chronological event stream sourced from likes, follows, comments, reviews, notes, reactions, playback, listening, purchases, and collection changes. Private by default; per-profile and per-object visibility governs each public projection. Existing domain state remains authoritative. |
| Smart Library and custom views | Library discovery and saved filters | Reusable typed filters for genre, franchise, decade, language, completion, format, favorites, and user-defined predicates. A saved view queries the profile's existing accessible library. |
| Smart Playlists and Smart Collections | Shared rule engine plus playlist/collection services | One validated, versioned predicate model powers dynamic playlist or collection membership. The destination controls ordering and presentation; the rules engine does not create another catalog. |
| Explainable recommendations | Recommendation service | Explicit strategies include similar title, likes, actor, director, franchise, genre, and discovery outside the profile's usual patterns. Each result reports why it appeared and which sources were used; users can tune source weights and exclusions. |
| Deep media relationships | Canonical media graph | Typed edges connect actor/character/work, director/work, song/album/movie, work/franchise/universe, edition/version, product/media, and physical/digital editions. Edges retain provenance and can explain navigation or recommendations. |
| Physical media ownership | Physical release, disc, and account library services | Preserve physical item, format, box set/discs, edition/version, current and historical ownership, condition, acquisition details, import provenance, and server availability separately from canonical work identity. Multiple physical editions can resolve to one canonical work. |
| Owned library and discovery | Library service plus federated search | Owned library queries include only validated acquired/imported media. Search may also return external catalog works, people, products, or providers, but labels discovery results separately and never inserts them into the library. |
| Cross-device continuity | Account/profile sync and playback sessions | Sync resume position, watch progress, likes, playlists, collections, subtitle/audio preferences, and X-Ray context, while each home server continues to own actual media files. |
| Accessibility | Shared app/player accessibility settings | Screen reader semantics, high contrast, text scaling, keyboard/controller focus, reduced motion, audio description, SDH/CC, subtitle styling, and playback preferences are available consistently across surfaces. |
| Offline behavior | Local cache and sync outbox | Cache appropriate metadata and X-Ray manifests for downloaded media; allow offline library browsing where data is present; queue eligible actions with idempotency keys; reconcile when the account/server reconnects. Show stale or pending state honestly. |
| Privacy controls | Profile privacy and object visibility | Keep profile, stories, playlists, collections, likes, reviews, activity, and purchases independently configurable. Apply visibility checks before activity publication, search inclusion, sharing, or notification delivery. |
| Unified notifications | Notification preferences and event routing | Route new episodes/library media, story interactions, comments, collection changes, wishlist availability, order updates, server status, Group Watch, and followed-entity releases through shared per-profile preferences and delivery channels. |
| Universal Queue | Queue and playback session service | One typed queue for compatible movies, episodes, tracks, and other playable items; play next/later, reorder, remove, save, and restore across devices. Queue entries keep canonical work and exact playable version/server availability separate. |
| More Like This intelligence | Similarity and recommendation service | Available from supported works, music, user lists, and products. Similarity can combine metadata, graph relationships, profile behavior, and analyzed content characteristics, with source explanations and profile controls. |
| Franchise / universe navigation | Canonical media graph and collection presentation | Dedicated views offer release, chronological, and story order plus movies, shows, specials, characters, related music, editions, and connected works. Ordering is sourced and labeled rather than inferred from title matching alone. |
| Advanced watch/listen sessions and Smart Continue | Playback sessions and profile activity | A session can resume work, exact version, audio/subtitle selection, position, speed, X-Ray state, queue, and Group Watch context. Continue surfaces include video, music, unfinished lists, resumed group sessions, recently started, and recently abandoned items where supported. |
| Personal tags and advanced sorting | Profile metadata and reusable list controls | Profile-owned tags such as Comfort or Rewatch can drive search, filters, recommendation inputs, and dynamic lists. Common sorts include added/played time, alphabetic, release, rating, duration, likes, completion, and custom order. |
| Duplicate and edition intelligence | Canonical work, edition, and media-version identity | 4K, Blu-ray, DVD, extended/director's cuts, remasters, and language editions resolve as related editions/versions of a work while preserving their distinct physical provenance and playback timelines. Candidate matches require evidence and never silently merge editions. |
| Home-server intelligence | Server health, library index, and playback negotiation | Show server reachability, capacity, media/version availability, transcoding support, network conditions, and health. Client responses expose safe status and stable identifiers, never private filesystem paths such as `relative_media_key`. |
| Automatic metadata repair | Metadata curation and identity resolution | Detect candidate matches, show evidence and confidence, suggest corrections, preserve user edits/provenance, and require safe resolution when editions or works could be conflated. |
| Household-aware experiences | Account, profile, access policy, and shared library | Keep recommendations, likes, history, playlists, collections, and privacy per profile while allowing explicitly shared account libraries and respecting profile access rules. |
| Audit and recovery history | Account/profile audit event service | Record appropriate create/update/add/remove/like/watch/review/purchase changes with actor, target, time, and idempotency/correlation data. Use for sync diagnosis and user recovery; apply retention and privacy policy, and do not equate audit logs with public activity. |

## Shared rules, events, and identity

Smart views and dynamic collections use a bounded rule language, not arbitrary executable expressions. Predicates reference canonical metadata and profile state, define missing-value behavior, and are validated before save. Examples include `liked AND resolution >= 4K AND watch_status = unwatched` or `franchise_id = ...`. Rule evaluation uses the user's accessible library and current privacy/access permissions.

The activity center is a projection of domain events, not a replacement transaction log. It may reference an existing like, review, watch, or collection change. Deleting or hiding an activity entry must not silently undo the underlying domain action. Public activity is generated only after object-specific privacy checks.

Canonical works, media versions, retail editions, account physical items, physical discs, disc contents, imported files, and playback sessions remain distinct identities. Timestamps, X-Ray events, notes, and shared playback references that depend on a cut bind to the exact media version. One physical purchase can contain multiple discs and many feature/bonus contents without becoming unrelated purchases. The home server owns media bytes; application metadata, graph edges, ownership ledger, preferences, and sync state belong to application/account/profile services.

Every playlist, collection, queue, session, tag, note, and share reference is scoped to its owner and target type. Cross-device state uses canonical IDs, exact version IDs where needed, revision/cursor state, and idempotent mutations. No client receives a private server path; the backend resolves safe identifiers to authorized server media.

## Delivery order

1. Formalize canonical content IDs, action capabilities, permission checks, and adapters to current Likes, Collections/Playlists, Wishlist, Ratings, Reviews, Playback, and Share services.
2. Standardize profile privacy and an idempotent activity/event contract; build the activity center and personal timeline as projections.
3. Add one validated rule model and evaluate it for saved library views, smart playlists, and smart collections.
4. Expand graph coverage and attach explanations to X-Ray, search, and recommendation navigation.
5. Unify search and recommendation strategy/source controls over the canonical graph and accessible profile data.
6. Add sync/outbox behavior, notification routing, offline metadata manifests, and accessibility settings across all surfaces.
7. Complete physical item ownership, guided multi-disc import, duplicate/edition matching, server-file integrity, and availability without merging physical provenance into canonical work identity.
8. Deliver one cross-device queue/session and Smart Continue experience, followed by server intelligence and safe metadata repair.
9. Add personal tags, sorting, franchise/universe views, and More Like This on top of the shared graph and rule/recommendation services.
10. Add audit/recovery, household privacy and access projections, and universal sharing after the underlying sync and permission contracts are stable.

## Existing foundations and gaps

The repository already contains universal media categories, media editions and versions, typed media relationships, profile likes/wishlist/collections, ratings/reviews, recommendations, playback progress, and account notifications. The architecture extensions also define shared category assignments and media relationships in Supabase. A first shared media-action contract now routes detail reactions, music playlist additions, and collection additions through existing domain owners and records profile-scoped idempotent action events on the backend. The action layer is not yet present on every content surface, and it does not yet constitute a universal activity timeline, dynamic rules engine, federated global search, or durable offline outbox.

X-Ray is one consumer of these capabilities, not a parallel social/library system. See [X-Ray architecture](XRAY_ARCHITECTURE.md) for its version-bound scene timeline, spoiler policy, personalized sections, follows, and private notes.

This is the final major capability expansion for the master plan. Further work should deepen integration, reliability, security, performance, accessibility, and polish within these owners instead of increasing the capability count with overlapping categories.

## Connected product experience

The shared contracts that make this connected experience concrete—including universal entity identity, relationship evidence, capability metadata, page configuration, navigation context, event delivery, provider display policy, degraded operation, and centralized authorization—are specified in [Connected Platform Foundations](CONNECTED_PLATFORM_FOUNDATIONS.md). These are implementation foundations for the existing 500 owners, not a new capability range.

The goal of consolidation is a product that behaves as one connected platform. A movie can lead a user to like it, add it to a collection, explore franchise and release relationships, share a Story, receive friends' reactions, open a chat, start a Group Watch, discover merchandise, visit a creator store, join a Live Shopping event, earn a reward, and track an order. With the user's permissions, those interactions can contribute to activity and recommendations. Each step uses the existing owner for identity, social actions, commerce, notifications, and personalization rather than creating a movie-specific copy of each system.

```text
MEDIA PLATFORM       Movies · TV · Music · Home Server
SOCIAL PLATFORM      Stories · Chat · Groups · Communities
COMMERCE PLATFORM    Marketplace · Stores · Orders · Live Shopping
INTELLIGENCE         Search · Recommendations · Releases · Personalization
SHARED PLATFORM      Identity · Notifications · Security · Analytics · Sync
```

These are architectural groupings over canonical capabilities, not additional capability inventories or independent implementations. Shared services keep behavior consistent across contexts, connect journeys between surfaces, and let improvements to an owner benefit every consumer. New roadmap requirements should first map to an existing capability and extend its shared service where appropriate; add a new owner only when the user-facing responsibility has no existing owner.

## Universal franchise/saga graph extension

The franchise foundation is now explicitly multi-relational. `media_franchises` and `media_franchise_members` describe organizational membership, while `media_graph_edges` describes relationships between works. Relationship type and continuity effect are separate fields so a cameo, reference, visual influence, adaptation, or multiverse appearance can remain relevant without asserting shared continuity. This model applies equally to Marvel, Twilight, Wizarding World/Harry Potter, Fantastic Beasts, Fast & Furious, DCEU-era material, and future franchises.

The graph remains shared infrastructure for capabilities 31–48 and consumers such as Search, Recommendations, X-Ray, Collections, Timeline, Character/People exploration, Stories, Chat, Group Watch, Marketplace associations, and Store merchandising.

## TV Intro Library extension

TV Shows now has a dedicated `TV Intros` presentation surface driven by `MediaItem.tvIntros`. Indexed intros are bound to the exact media version with start/end offsets and optional season/episode context. The backend schema foundation is `tv_intros`. The home server remains the owner of media bytes; only safe identifiers and playback offsets cross the application boundary. This same metadata is intended to power intro replay, Skip Intro, X-Ray, My TV, and playback personalization.

## External rating provider adapters

The rating domain now has a provider adapter boundary. `ExternalRatingService` can fetch configured TMDB and OMDb-backed provider ratings, while `RatingService` continues to keep external provider records separate from profile ratings. Backend-only environment variables are used for provider credentials (`TMDB_API_TOKEN` and `OMDB_API_KEY`). Production use must satisfy each provider's licensing, attribution, rate-limit, and commercial-use requirements. IMDb also offers a licensed metadata/ratings program; direct licensed IMDb integration can replace or supplement the OMDb-backed adapter when appropriate.

## Connected-page rule

Every major surface should be able to resolve a current entity into the same connected context: franchise/saga, timeline, versions, people, characters, X-Ray, likes, collections, recommendations, reviews, releases, availability, social sharing, Group Watch, marketplace associations, and relevant commerce/live-shopping surfaces. A page links to canonical owners rather than implementing a local copy. This is the required direction for the amplified 500: more cross-page connectivity, not more feature-specific silos.

## Connected Experience Bar

`lib/connected_experience.dart` provides the shared presentation contract for cross-page navigation. It intentionally contains no domain logic. A page supplies canonical destinations such as Franchise, Timeline, People, X-Ray, Collections, Reviews, Releases, Shop, Stories, Chat, Group Watch, or Recommendations; each callback routes to the existing owner. The same component can therefore be reused by Home, Movie, TV, Music, Details, Player, X-Ray, Collections, Search, Stories, My TV, Marketplace, Storefront, Live Shopping, and Profile surfaces without creating page-specific copies of the underlying capabilities.
