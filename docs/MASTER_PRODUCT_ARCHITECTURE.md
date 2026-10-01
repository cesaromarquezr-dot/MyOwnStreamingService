# Master Product Architecture

## Purpose

This document is the source of truth for the product architecture. The service is organized by domain rather than by individual Flutter screens so the product can grow without coupling UI, business logic, storage, AI, or device infrastructure.

## Product Domains

1. **Media Platform** — media catalog, versions, relationships, people, metadata.
2. **Experience Platform** — Home, Library, Live, Music, Search, Player, X-Ray, Collections, Playlists, Themes.
3. **Social Platform** — Friends, messaging, posts, reviews, communities, sharing, watch parties.
4. **Server Platform** — logical servers, NAS/storage, agents, health, migration, devices.
5. **Import Platform** — disc detection, ripping, staging, probing, matching, verification, review, approval, NAS transfer, library registration.
6. **Commerce Platform** — marketplace, stores, products, inventory, cart, checkout, payments, orders, shipping, returns.
7. **Intelligence Platform** — Hey Media, AI intents, context, recommendations, user-controlled memory, automation.
8. **Identity & Governance Platform** — accounts, members, profiles, permissions, privacy, security, notifications, recovery, audit.

## Core Boundaries

- UI is not business logic.
- Business logic is not storage logic.
- AI is not authorization.
- Media metadata is not media ownership.
- A logical server is not physical NAS storage.
- An import is not a library item until it is verified and approved.
- One source of truth exists for every major identity.

## Account / Member / Profile

```text
Account
├── Owner identity (initially the email/login that created the account)
├── Members
│   └── One member may have multiple profiles
└── Logical home server
```

The owner is always authoritative. The owner may choose whether members can administer their own profiles. Self-management is granular and never grants account/server/member-management permissions implicitly.

### Profile content governance

Profiles use policy-based content levels, e.g. Little Kids, Kids, Older Kids, Teen, Mature, Unrestricted, Custom. The level is based on content classification metadata rather than the profile name.

Profile administration can include content level, explicit music/lyrics, social restrictions, purchase restrictions, theme/collection permissions, notification permissions, and profile protection. Profile PINs must never be stored as plaintext in normal profile JSON.

## Media / Library Identity

```text
Global media catalog
        ↓
Media version / edition
        ↓
Account library
        ↓
Logical server
        ↓
Physical storage on NAS
```

`media_catalog` identifies the canonical work. `media_versions` identifies exact editions/cuts. `server_media` identifies server ownership. Private storage keys never go to normal clients.

## Seasonal / Event Context

Seasonal classification is many-to-many. The same title can belong to multiple events without creating duplicate media records.

Example:

```text
The Nightmare Before Christmas
├── Halloween
└── Christmas
```

Collections, event associations, and themes remain separate concepts. The presentation engine resolves the active context; it never duplicates or modifies the underlying media record.

## NAS / Media Server Agent

Flutter should not be the primary SMB/NFS client for media streaming. The preferred path is:

```text
Flutter
  ↕ HTTPS / WebSocket
Cloud Backend
  ↕ secure agent channel
Local Media Server Agent
  ↕ SMB/NFS/etc. inside the home LAN
NAS
```

The cloud handles authentication, authorization, metadata, jobs, and coordination. The agent handles physical file access, range streaming, NAS scanning, import/ripping, verification, and health. NAS credentials and private paths remain inside the agent boundary.

## Import / Ripping

```text
Disc
 ↓
Local Agent
 ↓
Rip / Digitize
 ↓
Local staging
 ↓
Probe / analyze
 ↓
Validate
 ↓
Metadata match
 ↓
Duplicate / version check
 ↓
User review
 ↓
Approval
 ↓
Transfer to NAS
 ↓
Verify
 ↓
Register library
```

Music imports can produce lossless FLAC from owned CDs according to the configured import profile. iTunes is not a required part of the architecture.

## Universal Playback

A shared playback engine supports movie, TV, music, radio, live TV, sports, trailers, and future user media. Players request short-lived authorized stream descriptors; they do not receive NAS credentials or raw filesystem paths.

## Hey Media / AI

```text
Voice / Text
 ↓
Intent + Context
 ↓
Permission check
 ↓
Confirmation when required
 ↓
Capability API
 ↓
Domain service / job
 ↓
Event / result
```

Purchases and destructive operations require confirmation. AI cannot bypass backend authorization.

## Events / Jobs

Long-running work is represented as jobs: import/rip, NAS migration, verification, backup/restore, library repair, recommendation refresh, and other background work.

Important events include media imported, import approved, playback started/finished, friend accepted, review created, order placed, payment completed, NAS offline, migration completed, theme changed, and profile policy changed.

## Performance

- Paginate lists and grids.
- Lazy-load expensive content.
- Use server-side filtering and debounced search.
- Cache posters, metadata, and theme configuration where appropriate.
- Avoid routing large media through cloud storage.
- Use background jobs instead of long-running HTTP requests.
- Keep sensitive/dynamic state on stricter freshness policies.

## Security

- Backend authorization is authoritative.
- Flutter never receives service-role keys, NAS credentials, raw password hashes, raw session secrets, payment card numbers/CVV, or private storage paths.
- Every important operation records actor, account, resource, action, time, and result in the audit trail.
- Session identity distinguishes owner vs member even when both operate on the same account.
- Profile restrictions are enforced server-side.

## Graceful Degradation

The UI should continue to provide metadata, search, social, and offline-aware status when a NAS, metadata provider, AI service, or other external dependency is temporarily unavailable. Playback/import features should report their dependency state and queue/retry work where appropriate.

## Development Rule

Feature additions should extend a domain capability or shared service. Avoid implementing business rules directly inside individual Flutter screens or duplicating the same media/permission/ownership concepts in multiple places.
