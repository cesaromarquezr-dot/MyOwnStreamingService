# Home Server Backend

The Dart backend exposes the authenticated API used by the Flutter/web clients.

The backend is organized into the following layers:

* `arm/` — ARM integration, physical-media ingestion, verification, and import planning.
* `routes/` — HTTP API endpoint handlers and request validation.
* `services/` — business logic and external-service orchestration.
* `models/` — API/domain objects shared by backend subsystems.
* `database/` — application persistence abstraction and local backend state.
* `supabase_store.dart` — server-side Supabase persistence for account/application metadata.
* `server.dart` — HTTPS/HTTP server startup, middleware, routing, CORS, security headers, and self-hosting controls.
* `config.dart` — environment-driven deployment configuration.
* `self_hosting_security.dart` — trusted-proxy, client-IP, VPN, and rate-limit enforcement.

Physical movie, television, music, and disc files remain on the user's managed home/media server. Central persistence stores account/application metadata rather than becoming a central media warehouse.

---

## Deployment architecture

The intended production network is:

```text
Internet
   │
   ▼
Cloudflare
   │
   ▼
Firewall / Router
   │
   ▼
NGINX Proxy Manager
   │
   ▼
Dart Home Server Backend
   │
   ├── Database / Supabase metadata
   ├── NAS / local media storage
   ├── Optical drives / ARM
   └── Transcoding / playback services
```

The Flutter/web client communicates with the authenticated backend API. The client is not installed as the home server itself.

For a physical deployment:

1. Mount the media/NAS storage into the server environment.
2. Connect configured optical drives to the ARM/server environment.
3. Configure the backend media paths through environment variables.
4. Configure the ARM endpoint through `ARM_SERVER_URL`.
5. Configure TLS according to the deployment:

   * Dart terminates HTTPS directly, or
   * NGINX Proxy Manager terminates public HTTPS and forwards traffic to the backend.
6. Configure trusted-proxy settings when the backend is intentionally restricted to the reverse proxy.
7. Keep service-role credentials and other backend secrets exclusively on the server.

Example environment configuration includes:

```text
SERVER_HOST
SERVER_PUBLIC_URL
BACKEND_TLS_ENABLED

SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY

ARM_SERVER_URL
ARM_USERNAME
ARM_PASSWORD

MEDIA_ROOT

TRUSTED_PROXY_CIDRS
REQUIRE_TRUSTED_PROXY
PROXY_SHARED_SECRET

ALLOWED_ORIGINS
VPN_CIDRS
RATE_LIMIT_PER_MINUTE

TRANSCODE_MAX_CONCURRENT
TRANSCODE_CACHE_ROOT
```

Secrets must never be embedded in Flutter source code or returned through the public API.

---

## Account/server deployment model

The current production model is:

```text
Account
 └── Managed Home/Media Server
      ├── NAS / storage
      ├── Media library
      ├── ARM / optical drives
      ├── Playback services
      └── Transcoding
```

The current subscription architecture assumes one managed home/media server per account in the applicable subscription tier.

Profiles belong to accounts rather than individual physical servers. This allows profiles associated with the same account to access that account's server remotely, including from different houses.

Each physical server deployment runs the same backend code but is associated with its account.

The Flutter/web application remains the client application. It does not become the server merely because it is used remotely.

---

## Authentication and account security

Authentication is handled by the backend rather than trusted to the client.

The backend is responsible for:

* account credentials;
* member identities;
* account memberships;
* profile ownership;
* sessions;
* password verification;
* password recovery;
* security questions;
* MFA challenges;
* subscription access checks;
* session revocation;
* security-event auditing;
* trusted-proxy validation;
* request rate limiting.

Backend-only credentials include:

* password hashes;
* security-answer hashes;
* MFA challenge hashes;
* service-role keys;
* ARM credentials;
* payment-provider credentials;
* proxy shared secrets.

These values must never be returned to Flutter/web clients.

Supabase service-role access is server-side only.

---

## Profiles and cross-account membership

An account can contain multiple profiles.

Profiles are persisted independently so application state can be associated with a specific profile without creating another account or home server.

Account membership is separate from the physical server.

A member identity can belong to more than one account:

```text
Member Identity
 ├── Account A membership
 └── Account B membership
```

This allows invited users to participate in multiple accounts while retaining separate account authorization boundaries.

The backend must always resolve:

```text
authenticated identity
        ↓
account membership
        ↓
profile ownership
        ↓
resource authorization
```

An authenticated identity alone is not sufficient authorization to access another account's media.

---

## Cross-account Group Chat

Group Chat is a backend-coordinated feature.

A chat room can contain profiles from different accounts:

```text
Account A
 ├── Profile A1
 └── Profile A2

Account B
 ├── Profile B1
 └── Profile B2

        │
        ▼

    Group Chat Room
```

The backend owns:

* room membership;
* invitations;
* participant authorization;
* messages;
* room state;
* account/profile relationships.

Group Chat does not require copying users' physical media into central storage.

---

## Cross-account Group Watch

Group Watch is also cross-account.

The backend coordinates playback while each participant continues using media authorized by their own account/server.

Conceptually:

```text
                Backend
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
 Account A Server       Account B Server
        │                     │
   Local Media            Local Media
        │                     │
        └──── Playback State ─┘
```

The backend is responsible for:

* resolving invited profiles;
* validating account/profile membership;
* validating media availability;
* validating authorization;
* negotiating compatible playback information;
* synchronizing playback state;
* managing participant state;
* handling invitations and session lifecycle.

The physical media itself does not need to be transferred into central storage.

A participant's authorization to play media remains tied to the server/account that actually owns or exposes that media.

---

# Storage subsystem

Storage is a first-class backend subsystem.

See:

```text
docs/STORAGE_ARCHITECTURE.md
```

for the detailed HDD/SSD, RAID, backup, and UPS architecture.

The backend can expose authenticated storage information through:

```text
GET /api/v1/storage/system
```

The storage subsystem is intentionally separated from destructive storage administration.

The backend may report:

* filesystem capacity;
* available space;
* storage pools;
* RAID state;
* degraded/rebuild state;
* backup state;
* UPS state;
* configured media categories;
* storage allocation information.

Read-only monitoring must not silently perform destructive filesystem, RAID, or backup operations.

Physical storage remains on the user's managed server.

---

# Home-server media model

The backend treats the home server as the authoritative location for physical media files.

Central metadata can describe a locally hosted item:

```text
Account
  │
  └── Home Server
        │
        ├── Server Media
        │      └── Local media identifier
        │
        └── Media Catalog
               └── Shared metadata
```

The central metadata layer can contain:

* title;
* media type;
* year;
* descriptions;
* artwork references;
* trailer metadata;
* catalog relationships;
* server/media identifiers;
* availability state;
* file-size metadata.

It does not turn the central database into a copy of the user's physical media library.

---

# ARM physical-media ingestion

ARM is the automated physical-media ingestion layer.

The intended pipeline is:

```text
Optical Drive
     │
     ▼
Disc Detection
     │
     ▼
Disc Scan
     │
     ▼
Physical Release
     │
     ├── Disc 1
     │    ├── Main Feature
     │    ├── Bonus Feature
     │    └── Trailer
     │
     └── Disc 2
          ├── Main Feature
          └── Bonus Feature
     │
     ▼
Verification
     │
     ▼
Metadata Resolution
     │
     ▼
Import Review / Plan
     │
     ▼
Library Import
```

ARM must preserve the relationship between:

```text
Physical Release
    ↓
Physical Disc
    ↓
Disc Content
    ↓
Library Media
```

A bonus feature must not automatically become a second primary movie.

Examples of distinct disc content include:

* primary feature;
* episode;
* deleted scene;
* commentary;
* trailer;
* bonus feature;
* soundtrack/music;
* data content;
* other verified content.

The ingestion pipeline should preserve all detected content rather than discarding non-primary material.

---

# Physical release identity

A physical release represents the actual packaged release rather than merely a title string.

Relevant metadata can include:

* release title;
* release type;
* edition;
* barcode;
* country;
* region;
* release year;
* discs;
* metadata provenance.

A release can contain multiple physical discs.

Ingestion order must not determine identity.

For example, scanning Disc 2 before Disc 1 must still allow both discs to resolve to the same physical release when verified metadata identifies them as belonging together.

Title matching alone must not be treated as authoritative physical-release identity.

---

# Music ingestion

Music separates the physical release from the canonical recording.

The model is:

```text
Music Release
 └── Medium
      └── Track
           └── Canonical Recording
```

A recording may appear in multiple releases.

For example, the same canonical recording can exist on:

* an artist album;
* a soundtrack;
* a compilation;
* another physical release.

The backend therefore avoids creating a new canonical recording merely because the same recording was encountered through another release.

Preferred identity signals include:

* ISRC;
* verified release metadata;
* audio fingerprint;
* duration;
* artist relationships;
* other authoritative metadata.

Title matching alone is insufficient for canonical recording identity.

---

# Lossless music archive

Music imports prefer:

```text
FLAC
```

as the lossless archive/master representation.

The lossless source is retained.

Playback-specific versions are derived only when required:

```text
FLAC master
   │
   ├── Direct Play
   │
   ├── AAC
   │
   ├── MP3
   │
   └── Opus
```

Derived playback files are disposable representations and must not replace the original lossless archive.

---

# Metadata and verification

ARM metadata is provider-neutral.

Metadata may describe:

* artwork;
* posters;
* descriptions;
* cast;
* directors;
* artists;
* albums;
* release information;
* market/country;
* region;
* music identifiers;
* physical-release information.

Metadata must remain distinguishable from verified physical content.

The backend should not manufacture a physical relationship from an unverified title match.

Verification should establish, where possible:

* readable content;
* media type;
* audio/video streams;
* duration;
* file integrity;
* expected content classification;
* metadata provenance.

---

# Playback and transcoding

Playback prefers the least expensive representation that satisfies the target device.

The decision hierarchy is:

```text
Direct Play
    ↓
Remux
    ↓
Audio Transcode
    ↓
Full Transcode
```

Direct Play and remuxing should remain preferred whenever the target device can consume the source representation.

This prevents unnecessary CPU/GPU consumption.

Full transcoding is performed only when required by the playback target.

---

# Transcoding scheduler

Transcoding jobs use a bounded concurrent scheduler.

Configure the maximum number of simultaneous jobs through:

```text
TRANSCODE_MAX_CONCURRENT
```

Example:

```text
TRANSCODE_MAX_CONCURRENT=2
```

The scheduler prevents an unrestricted number of simultaneous FFmpeg processes from exhausting the home server.

Transcoding output is stored in a derived cache rather than replacing the original media.

The cache is disposable.

The architecture is:

```text
Original Media
      │
      ├── Direct Play ──────────────► Client
      │
      ├── Remux ────────────────────► Client
      │
      └── Transcode
             │
             ▼
       Transcode Cache
             │
             ▼
           Client
```

The original media remains authoritative.

---

# Recommendations

Recommendations are generated from application metadata and profile activity.

Signals can include:

* watched media;
* liked media;
* disliked media;
* genres;
* themes;
* actors;
* directors;
* artists;
* language;
* country;
* release relationships;
* adaptation relationships;
* series continuation;
* shared profile interests;
* recency;
* diversity constraints.

International and local productions can be connected through verified country/language and adaptation relationships.

These relationships allow related works to be surfaced without requiring the works to be treated as identical.

Recommendation scores represent algorithmic relevance/match calculations. They are not probabilities of a user watching a title.

---

# Marketplace / Shop architecture

Marketplace functionality is intentionally separate from entertainment metadata.

A title, actor, franchise, album, or other media entity does not automatically become purchasable.

The architecture separates:

```text
Entertainment Metadata
        │
        ▼
Entity Association
        │
        ▼
Merchant/Product Relationship
        │
        ▼
Eligible Offer
        │
        ▼
Purchase Flow
```

A Shop association can identify that a product or merchant is related to an entertainment entity.

That relationship alone does not establish:

* availability;
* stock;
* price;
* purchase eligibility;
* ownership;
* checkout authorization.

Actual Shop eligibility must be backed by a real merchant/product relationship.

The marketplace can therefore provide discovery patterns such as:

* search;
* filtering;
* sorting;
* categories;
* merchant associations;
* product discovery;
* local/social marketplace presentation;
* checkout flows;

without conflating marketplace metadata with the user's private media library.

---

# Supabase persistence boundary

Supabase is used for server-side application metadata and persistence.

Examples include:

* accounts;
* member identities;
* account memberships;
* profiles;
* subscriptions;
* payment sessions;
* security events;
* server registrations;
* server-media metadata;
* profile customization;
* account snapshots;
* marketplace entity metadata.

Supabase does not become the authoritative storage location for the user's physical movie, television, or music files.

The home server remains responsible for the actual media files.

---

# Application-state synchronization

The backend can synchronize sanitized account/profile application state with Supabase.

Client-provided snapshots are treated as untrusted input.

The server must never allow a client snapshot to overwrite backend-authoritative security information such as:

* password hashes;
* MFA state;
* security-answer hashes;
* subscription authorization;
* payment status;
* account ownership;
* server ownership.

Backend-authoritative state must come from the authenticated server-side models and persistence layer.

---

# Security boundaries

The backend should enforce security at multiple layers:

```text
Client
  │
  ▼
HTTPS / Reverse Proxy
  │
  ▼
Trusted Proxy Validation
  │
  ▼
Rate Limiting
  │
  ▼
Authentication
  │
  ▼
Account Authorization
  │
  ▼
Profile Authorization
  │
  ▼
Resource Authorization
  │
  ▼
Service / Database
```

Important principles:

* Never trust client-provided ownership.
* Never trust client-provided payment success.
* Never trust forwarded IP headers unless the immediate peer is a trusted proxy.
* Never expose service-role credentials.
* Never expose password material.
* Never use title matching alone as authoritative physical-media identity.
* Never treat metadata association as proof of marketplace eligibility.
* Never replace original media with derived transcoding output.
* Never move private home-server media into central storage merely to coordinate Group Watch.
* Keep security-sensitive decisions in the backend rather than Flutter.

---

# External infrastructure boundary

Some parts of the complete self-hosting architecture intentionally remain outside the Dart application:

```text
Cloudflare
Firewall
DDNS
NGINX Proxy Manager
Physical NAS
RAID controller
UPS
Operating system
Physical optical drives
```

The Dart backend integrates with these components through configuration, trusted-proxy controls, filesystem access, monitoring, APIs, and service boundaries.

The application can therefore implement the software-side portion of the self-hosting architecture without pretending that Flutter/Dart itself replaces the physical or network infrastructure.

---

# Current implementation boundary

The backend is designed so that the same application code can run in:

* local development;
* a Windows home server;
* a Linux home server;
* a NAS-adjacent server;
* a reverse-proxy deployment;
* a directly TLS-terminated development deployment.

Environment variables determine deployment-specific details such as:

* network binding;
* public URL;
* TLS mode;
* proxy trust;
* storage paths;
* ARM endpoint;
* Supabase credentials;
* transcoding concurrency;
* marketplace integrations.

This keeps deployment-specific secrets and infrastructure details out of the Flutter application and source-controlled application logic.
