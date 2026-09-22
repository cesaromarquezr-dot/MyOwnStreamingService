# Services

Business logic for authentication, recommendations, ARM, search, payments, reviews, storage, playback/transcoding, marketplace, sports, and remote access.

Services sit between HTTP routes/controllers and persistence or external infrastructure.

## Responsibilities

Services should:

* validate business rules and domain invariants;
* normalize and validate identifiers and user input;
* enforce account/profile ownership and authorization rules;
* coordinate database operations;
* keep security-sensitive operations server-side;
* perform external API or provider integration through controlled interfaces;
* preserve provenance and canonical media identities;
* return domain models or service results rather than HTTP responses;
* avoid exposing secrets, credentials, password hashes, session tokens, or internal exceptions;
* keep destructive filesystem/storage operations behind explicit, authorized service boundaries;
* use UTC timestamps for persisted security and business events where practical;
* use cryptographically secure randomness for security-sensitive identifiers, tokens, and one-time codes.

## Major service areas

### Authentication and accounts

Authentication services handle:

* account creation and login;
* password hashing and verification;
* sessions and session rotation/revocation;
* MFA challenges;
* password recovery;
* member invitations;
* account/profile management;
* authentication and security auditing.

Password material and other sensitive authentication data must never be returned through public account serialization.

### Recommendations and media intelligence

Recommendation and intelligence services handle:

* profile-aware recommendations;
* watch/like/dislike signals;
* recommendation history;
* media similarity;
* metadata relationships;
* artwork and device/session intelligence.

Recommendations must remain algorithmic suggestions rather than implying ownership, availability, purchasing rights, or playback rights.

### ARM and physical-media ingestion

ARM services handle the boundary between physical media and the digital library:

* optical-disc discovery;
* physical release/disc/content modeling;
* main-feature and bonus-content classification;
* metadata verification;
* ripping/import jobs;
* music-release and canonical-recording relationships;
* import review and verification;
* provenance preservation.

A physical disc must not automatically become a movie or episode. Bonus material, trailers, deleted scenes, commentary, music, and data content retain their own classifications.

Music releases and canonical recordings are separate identities. The same recording may appear on multiple releases without creating duplicate canonical recordings.

### Search

Search services provide:

* global media search;
* type-specific filtering;
* actor/director/reference search;
* deterministic relevance ordering;
* bounded query and result sizes.

Search results do not imply that a title is playable, purchasable, or legally available to the requesting user.

### Payments and subscriptions

Payment and subscription services handle:

* checkout-session creation;
* subscription lifecycle;
* payment state;
* processor verification;
* payment failure/cancellation;
* renewal.

Client-supplied processor transaction identifiers are not sufficient evidence of successful payment. Payment activation must occur only after server-side verification or an equivalent trusted processor/webhook flow.

### Reviews and ratings

Review and rating services keep separate concepts separate:

* provider ratings;
* personal profile ratings;
* user reviews;
* global/public review presentation.

Provider scores must not be fabricated or silently combined with a user's personal rating.

Personal ratings use the supported half-star range and are stored independently from external provider scores.

### Playback and transcoding

Playback services handle:

* media access decisions;
* media probing;
* playback capability matching;
* direct-play/remux/transcode decisions;
* transcoding scheduling;
* derived playback-cache management.

Original media files are never treated as disposable transcoding cache.

Transcoding outputs must remain within the configured derived-cache boundary and must not replace source media.

### Marketplace and shop

Marketplace services handle:

* global shop-entity discovery;
* entity synchronization;
* merchant-offer eligibility;
* marketplace associations.

Discovering a relationship between media and a merchant entity does not establish that an item is currently purchasable. Actual purchasing eligibility requires a valid merchant offer.

Private source-server media remains separate from globally synchronized marketplace metadata.

### Storage and home-server services

Storage services provide read-only or controlled business operations around:

* filesystem capacity;
* storage pools;
* RAID status;
* backup status;
* UPS status;
* storage requests;
* server health;
* home-server capacity reporting.

Destructive filesystem, RAID, backup, or storage operations must not be exposed merely because a monitoring endpoint exists.

### Remote access

Remote-access services handle:

* one-time worker registration codes;
* remote worker authentication;
* worker lifecycle;
* import-job queuing;
* worker/job ownership;
* job status.

One-time registration credentials must be short-lived, single-use, and generated with cryptographically secure randomness.

## Persistence boundary

A service may use the in-memory database during development, but production state that must survive a process restart should be persisted through the configured database/Supabase layer.

Security-sensitive operations requiring atomicity should ultimately be implemented transactionally where possible, including:

* one-time credential consumption;
* payment completion/idempotency;
* session revocation;
* account mutations;
* remote-worker registration;
* storage-request state transitions.

## External infrastructure boundary

Services may integrate with external infrastructure, but infrastructure that lives outside the Dart application remains outside this directory.

For example:

```text
Internet
   ↓
Cloudflare
   ↓
Firewall
   ↓
NGINX Proxy Manager
   ↓
Dart backend
   ↓
Services
   ↓
Database / Media Storage / ARM / External Providers

The backend can implement application-level authentication, authorization, proxy-awareness, TLS configuration, API security, media access control, and provider integrations. Cloudflare, firewall rules, DNS/DDNS, reverse-proxy configuration, VPN networking, and physical storage infrastructure remain deployment concerns.

## Service-layer security principles

All services should follow these principles:

1. **Fail closed** for authentication, authorization, payment verification, and ownership checks.
2. **Do not trust client-provided authorization state.**
3. **Do not log secrets or credential material.**
4. **Bound external input** by length, format, and allowed values.
5. **Validate identifiers before database or filesystem access.**
6. **Use account/profile ownership checks** before modifying user data.
7. **Use HTTPS for externally configured sensitive endpoints.**
8. **Treat external metadata as untrusted input.**
9. **Preserve media provenance instead of inferring ownership or identity.**
10. **Keep HTTP concerns in routes** and business rules in services.
11. **Prefer deterministic behavior** where recommendations or search results are ordered.
12. **Use durable persistence for state that must survive process restarts.**
13. **Use atomic operations for security-sensitive state transitions.**
14. **Never interpret metadata relationships as authorization or purchasing rights.**