# Connected platform foundations

This architecture pass consolidates shared foundations for the existing 500 canonical capabilities. It expands the canonical architecture and capability owners 31–48, 38, 450, and 460; it does not create a new capability inventory. These foundations should be implemented before adding more isolated page features.

## Owned-media product invariant

The core product is the account's acquired physical-media collection and the library of media imported/ripped from physical media that account owns. A title appearing in external metadata, search, recommendations, a franchise graph, a store, or a release feed does not make it a library item. External providers enrich known entities with metadata, artwork, ratings, releases, and relationships; they never create an owned library record. Discovery results and the owned library are separate surfaces and are labeled as such. Broader discovery can be entered explicitly without changing library membership.

Create a library media record only from an approved acquisition/import workflow tied to an account ownership record and an imported server file. Searching, opening a metadata page, adding a provider result to a collection, or purchasing a marketplace listing does not by itself add playable media to the library. A physical purchase progresses through receipt/ownership, identification, import/rip, validation, and server registration. Marketplace purchase records remain commerce records until the user receives and registers the physical item and imports it.

This is a product rule, not a claim that every existing code path enforces it yet. Migrate current catalog/library boundaries and make this invariant explicit in backend validation before calling the owned-library flow complete.

## 11. Physical ownership ledger and provenance chain

Track each physical copy as an account-scoped **Physical Item**, distinct from the canonical work, retail edition, and disc definition. The item can hold title, format (4K UHD, Blu-ray, DVD, CD, other), region, edition, release date, barcode/catalog number, disc count, acquisition date, condition, current ownership status, notes, artwork, and included extras. Ownership states are `OWNED`, `LOANED`, `LOST`, `DAMAGED`, `SOLD`, and `ARCHIVED`. Record state transitions as history: selling, losing, or archiving an item does not erase its acquisition, edition, imported files, playback history, reviews, notes, photos, or prior collection membership. Current ownership and historical ownership are queryable separately.

The provenance chain is:

```text
Account Ownership Record → Physical Item → Edition → Media Version
  → Physical Disc(s) → Disc Content → Import/Rip Job → Imported File(s) → Home Server
  → Owned Library Media
```

One purchase/box set can contain many discs; each disc can contain feature films, episodes, commentaries, deleted scenes, documentaries, trailers, alternate cuts, galleries, or bonus music. Disc contents are typed and can link to their own canonical work/version when appropriate. Bonus material is not duplicated as another copy of the main feature, and a box set is not represented as unrelated purchases. A physical item may have no imported copy yet; a server file may have provenance to its exact physical item, disc/content, edition, version, account, and server.

## 12. Guided ingestion and version identification

Make disc insertion a reviewable workflow rather than a direct file-add action:

```text
Insert/import disc → identify disc → identify edition → identify version
  → read disc structure → choose contents → import/rip → validate
  → register on home server → create/update owned library media
```

For multi-disc releases, preserve a shared physical item/release relationship across all disc jobs. Match edition/version using evidence including barcode, region, runtime, disc structure, audio/subtitle tracks, extras, and release date. Metadata providers supply candidates; they do not decide ownership. Ambiguous matches require user review and retain confidence/source information. CD ingestion follows the same pattern through album, physical medium, tracklist, rip, and music library.

The library record is committed only after the ownership/import event is validated and the imported file is registered to an authorized home server. Failed, canceled, or pending jobs remain in the import workflow and do not create a falsely playable library item.

## 13. Server-file integrity and centralized jobs

Every imported file records safe provenance references plus technical/integrity metadata where available: checksum/hash, size, codec, resolution, HDR format, audio/subtitle tracks, chapter count, duration, integrity status, last verified time, storage location reference, and backup status. Storage locations and server identifiers are access-controlled; private filesystem paths are never exposed to clients. Integrity checks can report verified, needs revalidation, corrupt, or unknown without deleting ownership history.

Use one job framework for disc import, audio ripping, video transcoding, metadata matching, artwork acquisition, subtitle/chapter/intro detection, integrity checks, backups, and version analysis. Jobs expose typed state, progress, safe errors, retryability, correlation IDs, and provenance links. This amplifies home-server/storage and transcoding capabilities (89–101), releases/availability (156–169), and backend/synchronization (450–476, especially 462–463); it does not become a separate copy of each domain service.

## 14. Owned-library recommendations and collection intelligence

Normal Home recommendations and continue-watching prioritize media already in the owned/imported library: owned titles unwatched, imported alternates, incomplete owned sagas, and relationships among owned works. Broader discovery recommendations are clearly labeled and never silently populate the library. External rating pages in the library are reached through an owned library item; global provider ratings remain metadata for catalog/discovery where permitted.

Graph-aware collections can summarize owned works, physical items/discs, imported files, missing-from-server media, duplicate copies, bonus content, watched state, and upcoming releases. A franchise view can distinguish total franchise works from account-owned/imported works. A TV collection can distinguish seasons/discs owned from episodes imported. Physical acquisition, current physical possession, imported server copy, and playback availability are independent facts: a user may own a disc without a rip, have an imported copy from an owned disc, or preserve a historical record after selling the disc.

The Store is an acquisition surface, not a second streaming catalog. A marketplace purchase becomes physical ownership only after receipt/registration; library media is created only after the owned physical item's content is imported and validated. Do not automatically inject products, purchases, provider catalog entries, or streaming availability into the owned media library.

## 15. Capability ownership overlay

Name **Ownership & Physical Media Provenance** as an explicit cross-cutting capability group within the existing 500. It is not a new numbered range and does not renumber the map. Its responsibilities map primarily to 31–48 for canonical identity, edition/version matching and metadata provenance; 89–101 for physical items, discs, imports, files, servers, storage integrity and jobs; 116–128 for owned-library and collection projections; 156–169 for release/availability context; 282–296 and 332–341 for purchase and delivery evidence; and 477–486 for backup and recovery. The group has one documented owner/service boundary while each numbered capability retains its existing owner and implementation status.

## 1. Universal entity identity

One identity service resolves and issues stable internal IDs for every graph-addressable entity. Initial entity kinds include Media, Movie, Series, Season, Episode, Song, Album, Artist, Person, Character, Franchise, Universe, Collection, Store, Product, Seller, Livestream, Story, Message, Release, Physical Edition, and Home-Server File. The registry is extensible; entity kind is explicit and is not inferred from an ID prefix.

An entity reference has a stable internal ID, a kind, and optional provider identifiers. Provider IDs are aliases, not primary keys. Existing domain tables remain authoritative for their data; the registry provides shared identity and resolution rather than copying every domain record into a new universal table. Home-server files use opaque application IDs and never expose filesystem paths.

Relationships reference entity IDs and carry a type, direction, optional exact version, provenance, confidence, and timestamps. A relationship record can include `source_type` (dialogue, production metadata, provider, user, or editorial), a source reference, an optional source timestamp or span, and a confidence value. `continuity_effect` remains separate from relationship type. A `meta_reference` sourced from dialogue at `00:42:13` can therefore be discoverable without asserting canon continuity. Missing evidence remains unknown; it must not be presented as a sourced fact.

## 2. Version and availability identity

Keep the identity chain explicit:

```text
Canonical Work → Media Version → Physical/Digital Edition → Release → Actual Server Media
```

Each layer has its own stable ID and relationship. The graph can attach scenes, alternate endings, credits, audio tracks, subtitles, intros, bonus material, and other version-specific metadata to the exact Media Version. Playback sessions, X-Ray events, and offsets bind to that same version. A release or server file does not become a new canonical work. The server owns media bytes; the application stores safe references and availability state.

## 3. Capability registry

Promote the existing platform capability manifest into a metadata registry for the numbered 500 capabilities. A registry record includes capability number and name, canonical owner/service, implementation status (`planned`, `partial`, `enabled`, `disabled`, or `retired`), backend/UI surfaces, dependencies, feature-flag key, and permission policy reference. For example, capability 109 can identify `AudioSubtitleService`, player UI, profile-scoped preferences, and its media-version dependency; capability 170 can identify `MyTvService` with `partial` status.

The registry drives discovery, diagnostics, page composition, and feature availability. It is not an authorization grant: the UI may use it to hide or explain unavailable features, while backend policy checks remain authoritative. Keep status, deployment flags, user permissions, and runtime health as distinct fields so `partial` does not accidentally mean available to every user.

## 4. Shared page configuration

Generalize `PagePresentation` from visual tokens into a reusable page configuration consumed by Home, Library, Store, Seller Dashboard, My TV, artist, movie, and other pages. A page configuration can specify sections, layout, modules, visibility, ordering, density, theme, personalization, and permission requirements. Page types can define supported module catalogs and defaults; the shared engine validates and renders the configuration. Domain services still own module data and behavior. Unsupported modules and unauthorized content are excluded at render time.

The existing `PagePresentation` remains the visual-token foundation. Storefront customization is the first specialized consumer, not a separate configuration engine.

## 5. Canonical context

Cross-feature navigation carries a typed context containing the current entity ID, optional exact version ID, playback timestamp, profile ID, source surface, and optional related entity or session IDs. Context can be serialized into navigation state and deep links, subject to privacy and access policy. X-Ray, Timeline, Collections, Chat, Stories, Reviews, Group Watch, Shop, and Recommendations consume the same context contract so a transition preserves what the user was viewing without inventing page-specific parameter bundles.

Context is navigation state, not permission. Every destination re-resolves the referenced IDs and checks current access before returning protected information or allowing an action.

## 6. Shared events

Define a versioned domain-event contract for events such as `USER_LIKED_MEDIA`, `MEDIA_STARTED`, `MEDIA_FINISHED`, `MEDIA_RELEASED`, `STORE_FOLLOWED`, `PRODUCT_PURCHASED`, `STORY_CREATED`, `WATCH_PARTY_STARTED`, `LIVESTREAM_STARTED`, and `REWARD_GRANTED`. Events carry stable entity references, actor/account/profile scope where applicable, occurred-at time, schema version, correlation/idempotency key, and privacy classification.

Domain services remain the source of truth and publish events after successful changes. Activity, notifications, recommendations, analytics, release awareness, Stories, social, and personalization consume events through independent handlers. Consumers must be idempotent; event projections do not replace transaction records or grant access. Use a durable outbox for events that must survive process or network failure, with retry and dead-letter diagnostics.

## 7. Provider metadata and display policy

Provider-backed ratings and metadata retain provider, provider ID, value, retrieval time, expiry, region, language, source type, and applicable display policy. Provider snapshots stay separate from personal ratings and public reviews; scores are not silently averaged. Display policy records attribution and usage constraints needed by the renderer, while provider licensing and credentials remain backend concerns. The same provenance pattern applies to non-rating external metadata where relevant.

## 8. Offline and degraded operation

Model service availability separately for the application backend, Supabase, and each home server. The client distinguishes cached catalog/profile/library data from live server availability and marks stale data honestly.

```text
Online: backend + Supabase + home server available
Backend unavailable: show permitted cached profile/library/metadata; queue eligible idempotent changes
Home server unavailable: keep catalog and metadata visible; report playback unavailable due to server reachability
```

An absent title and an unreachable server are different states. Cache access remains subject to profile permissions and retention policy. Sync reconciles outbox operations when services recover; it must not duplicate purchases, social actions, or playback events.

## 9. Central authorization policy

Use one policy service and shared request context to evaluate actions such as CanView, CanEdit, CanShare, CanMessage, CanPurchase, CanSell, CanStream, CanHost, CanModerate, and CanManageStore. Decisions can depend on account, member role, profile, age/content controls, store role, ownership, resource, and visibility. UI controls can reflect decisions, but every backend operation enforces the same policy at the resource boundary. Policy responses should explain denial in a safe, user-facing way without exposing protected resource details.

## 10. Universal connection explorer

Provide one reusable graph-powered connection component. It accepts canonical context and a set of allowed relationship domains, then renders only supported, authorized connections. A movie can show franchise, universe, related works, characters, people, timeline, versions, scenes, references, influences, soundtrack, profile collections/likes/stories/chats, products, and Group Watch. An artist or product uses the same component with a different domain selection. Sections link to canonical owners; the component does not implement duplicate feature behavior.

## 16. Availability and ownership

Availability is a shared, time-sensitive projection over canonical entities, versions/editions, account/profile state, region, and server state. Preserve distinct dimensions instead of treating them as one status:

- **Access channel:** physical, digital, streaming, home server, or downloaded.
- **User state:** owned, not owned, wishlisted, or not applicable.
- **Service state:** available, unavailable, coming soon, region restricted, or unknown.
- **Scope:** account/profile, region, provider/service, exact version/edition, and server where relevant.

For example, `4K UHD — owned`, `Home Server — available`, `Digital — not owned`, and `Streaming — available in Mexico` can coexist for one work. Availability records include observation/source and freshness so a stale provider response is not presented as current. Search, Releases, Collections, Playback, Store, and Recommendations consume the same projection. A missing library item and a disconnected server remain distinct states.

## 17. Universal actions and contextual action menus

One entity-aware action layer resolves available actions from entity kind, canonical context, capability availability, permissions, and destination services. It routes Watch to a permitted playback source, Buy to Marketplace, Own to physical-edition tracking, Wishlist to the profile wishlist, Follow to release tracking, Share to Chat/Story, and Add to the appropriate Collection/Playlist/Queue. Entity-specific action sets can differ: media can be added to collections or watch queues, songs to playlists or music queues, and products to wishlists or carts. The shared layer owns presentation, pending/success/error states, idempotency, and destination selection; domain services retain business rules and records.

Context also shapes which actions and connections are emphasized. A player context for an exact Encore version and timestamp can offer its scenes, other versions, timeline, X-Ray, timestamp sharing, notes, and Group Watch. A Store context can prioritize edition comparison, seller, reviews, wishlist, and purchase. Both read the same graph and identity contracts while applying different surface policies.

## 18. Saved views and smart collections

Users can save named views over accessible canonical data, such as `Marvel Collector View` (release chronology, physical editions, preferred 4K, franchise grouping, versions) and `Watch View` (story chronology, resume-first, hide physical editions). A view stores a validated configuration against a page/list type and can be scoped to a profile, account, or shared collection. It reuses shared page configuration and bounded filter/sort rules; it does not snapshot or duplicate the underlying media records.

Collections can combine user-selected membership/order with optional graph-aware insights: missing franchise entries, owned editions, watched state, upcoming releases, and related products. User-created groupings and relationships are separately typed, attributed to their creator, and never overwrite provider/editorial relationships or canonical continuity assertions. A user can define `My Spider-Man Timeline` while sourced metadata independently records evidence-based graph edges.

## 19. Universal search, commands, and explanations

Extend Search/Discovery over entity identity, graph, profile data, availability, and permissions. Queries can find people, works, songs, unwatched library items, sellers, or shows by cast. Natural-language commands such as creating a collection from liked sci-fi movies are interpreted into a previewable, permission-checked operation over existing Search, Likes, and Collections owners. Commands must request confirmation before consequential writes and expose the resolved scope and resulting items.

Recommendations and other personalized surfaces carry structured explanation reasons, such as a liked related title, followed franchise, watched character connection, or upcoming regional release. A shared `Why this?` presentation renders those reasons from the actual inputs used. Do not fabricate explanations or expose another profile's private activity.

## 20. Metadata assertions and artwork

Externally sourced metadata is stored as attributed assertions rather than destructive field overwrites. An assertion records entity/property, source/provider, provider ID, value, confidence, retrieval time, region, language, and optional exact version. Canonical values are resolved from eligible assertions under a documented field-specific policy; all source assertions remain available for review and correction. This applies to titles, release dates, genres, credits, artwork, ratings, runtimes, episode numbering, and audio/subtitle metadata. For example, provider runtimes of 180–182 minutes can coexist with a home-server scan of 181:34 while a selected canonical display value retains its source and rationale.

Artwork is a first-class typed asset association supporting posters, backdrops, logos, banners, character art, portraits, album/store/product imagery, and alternates by region, edition, or version. Store asset source, dimensions/role, locale/version scope, rights/display policy, and profile preference where applicable. User artwork preferences select among eligible assets; they do not mutate shared provider metadata. Reuse the same resolver for cards, detail pages, and customizable page modules.

## 21. Change history, diagnostics, contract verification, and export

Maintain an access-controlled audit/history record for important changes such as metadata corrections, collection renames, store-theme edits, price changes, payout-destination changes, version additions, relationship edits, and review edits. Record actor, target, operation, time, correlation ID, and safe before/after references as policy permits. Audit history supports troubleshooting and security review; it is not automatically public activity and must not retain secrets such as payout credentials.

Provide an internal developer/admin diagnostics surface backed by the capability registry and health checks. It can report implementation status, backend route health, Supabase sync health, provider availability, background-job queues/failures, failed requests, and applied migration versions. Health and capability status are distinct: an enabled capability can have a degraded dependency, and a healthy route does not imply a capability is complete.

Cross-system contract verification should cover the identity/version/server-media/playback chain; franchise relationship/timeline/collection/search flow; and product/cart/checkout/order/shipment/review/loyalty flow. Tests should assert stable IDs, authorization boundaries, idempotency, unavailable/degraded states, and preservation of source/version context across each boundary. Keep these as integration contracts so implementation changes reveal regressions across distant capability owners.

Account export is a versioned, portable bundle for profiles, collections, likes, watch/listening history, ratings, reviews, playlists, Stories, notes, wishlists, purchases, preferences, saved page views, and user-authored relationships. Export policy must respect account/profile permissions and privacy; secrets, provider credentials, and private home-server paths are excluded. Include schema version and stable entity references, and document which records can be imported or restored.

## Ownership and implementation sequence

These foundations amplify existing owners: entity identity and relationship provenance map to 31–48 (especially 38); page configuration and capability metadata map to 450–465; eventing, context propagation, sync, and degraded operation map to 450–476 (especially 460); domain-specific experiences remain with their current owners. Authorization is shared infrastructure used by account, profile, social, playback, and commerce owners.

Implement in dependency order:

1. Stabilize entity references, the owned-library invariant, physical ownership ledger, import provenance, and version/edition/release/server-media links; add source assertions and relationship provenance.
2. Define capability metadata, authorization, context, and account/profile/region/server-aware availability; reconcile the registry with the 500-capability map.
3. Build guided ingestion and multi-disc content selection, then persist validated ownership/import/file/server links and technical integrity metadata.
4. Establish versioned events and a centralized job/outbox model; migrate activity, notification, recommendation, availability, and analytics consumers incrementally.
5. Generalize page configuration and saved views; build universal actions and the connection explorer over owned-library context, identity, graph, availability, and policy.
6. Constrain normal Home recommendations to owned/imported media, extend search with explicit discovery mode and previewable commands, and expose truthful explanations.
7. Complete cache manifests, service health, offline reconciliation, artwork selection, audit history, diagnostics, cross-system contract verification, and portable account export.

Treat each step as a foundation with explicit status and migration compatibility. Do not claim all 500 capabilities are implemented because they appear in the registry.
