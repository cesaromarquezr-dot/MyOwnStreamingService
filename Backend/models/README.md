````markdown
# Models

Typed domain and API models shared by backend services and routes.

The model layer defines the data contracts used throughout the
Flutter/home-server architecture. Models should remain focused on
representing domain state, validating/normalizing that state, and
serializing it for persistence or API transport.

Business operations such as database writes, transcoding, media ripping,
authentication, payment processing, and external-provider synchronization
belong in services, repositories, middleware, or route handlers rather than
inside the models themselves.

---

## Model-layer responsibilities

Models are responsible for:

- typed domain fields
- safe defaults
- JSON serialization/deserialization
- lightweight validation
- normalized read-only helpers
- immutable-style `copyWith` updates where appropriate
- preserving backwards-compatible API shapes when practical
- representing relationships between domain objects
- distinguishing canonical identities from physical files/releases
- keeping sensitive fields out of public JSON by default

Models should generally **not**:

- open database connections
- write files
- execute FFmpeg or other media tools
- contact external APIs directly
- authenticate users
- authorize requests
- process payments
- schedule background jobs
- mutate persistent state without going through a service/repository

---

# Core media models

## `media.dart`

`Media` represents a library-facing media item such as a movie or TV
program.

It contains presentation and catalog information including:

- title
- media type
- release information
- descriptions
- posters and artwork references
- genres, themes, and tags
- people and franchise relationships
- language/country information
- TV episode information
- availability
- physical-media provenance
- canonical music-recording references when applicable

Physical provenance is intentionally separate from the identity of the
media itself.

For example:

```text
Media
└── Spider-Man
    └── physicalDiscId → Disc 1
````

A physical disc is not itself a new movie.

---

## `media_work.dart`

`MediaWork` represents a canonical creative work.

It is intended to describe the work independently from:

* a physical release
* a disc
* a ripped file
* a playback session
* a transcoding job
* a specific retail edition

This separation allows multiple releases or files to reference the same
underlying work.

---

## `media_relationship.dart`

`MediaRelationship` represents a typed relationship between canonical
media entities.

Examples of relationship categories can include:

* sequel
* prequel
* adaptation
* franchise membership
* related work
* soundtrack relationship
* episode relationship

Relationship types remain extensible rather than being restricted to a
hard-coded list.

The persistence layer is responsible for enforcing identity,
deduplication, and relationship integrity.

---

## `media_artwork.dart`

`MediaArtwork` represents artwork associated with a media entity.

Artwork may originate from:

* local storage
* an external metadata provider
* an imported physical release
* another catalog source

The model does not download or manage artwork itself.

---

# Physical media and ARM models

The ARM model family represents physical releases and their contents.

The important distinction is:

```text
Physical release
    ↓
Physical disc
    ↓
Disc content
    ↓
Canonical media/content
```

A physical release is not automatically equivalent to one media item.

For example:

```text
Movie release
├── Disc 1
│   └── Main Feature
└── Disc 2
    ├── Deleted Scenes
    ├── Commentary
    └── Trailers
```

The bonus material must not be represented as another copy of the movie.

## `arm_models.dart`

ARM models include concepts such as:

* physical releases
* physical discs
* disc contents
* music releases
* music mediums
* music tracks
* canonical music recordings
* ARM rip jobs
* verification results
* drive information
* disc detection
* import results

Disc content types distinguish things such as:

* feature
* episode
* bonus feature
* music
* data
* other

Disc types can distinguish:

* DVD
* Blu-ray
* UHD/4K
* CD
* audio CD
* data disc
* unknown

---

# Music identity

Music requires a separate identity model from physical releases.

The intended hierarchy is:

```text
Music release
    ↓
Medium
    ↓
Track
    ↓
Canonical recording
```

For example:

```text
Artist album
└── Track
    └── Recording A

Movie soundtrack
└── Track
    └── Recording A
```

The album track and soundtrack track can therefore point to the same
canonical recording.

This prevents the library from creating duplicate canonical songs merely
because the same recording appears on multiple releases.

## `music_media.dart`

`MusicMediaVersion` represents a particular stored media version/file of a
track.

It may preserve:

* source format
* archive format
* lossless state
* file path
* artwork
* artist/album metadata
* track/disc numbering

Lossless archive formats are preserved as library-quality sources rather
than being treated as temporary streaming transcodes.

---

# Playback and transcoding models

## `media_capabilities.dart`

`MediaCapabilities` describes what a playback target can support.

It represents capabilities such as:

* video codecs
* audio codecs
* containers
* resolution
* HDR
* video/audio support

It does not itself decide whether a file should be transcoded.

---

## `playback_profile.dart`

`PlaybackProfile` represents the playback strategy selected for a client.

Possible modes include:

* direct play
* remux
* audio transcode
* full transcode

It represents a playback decision rather than the server's physical
transcoding capacity.

---

## `transcoding_capacity.dart`

`TranscodingCapacity` describes the server's configured resource envelope.

It includes:

* maximum concurrent video jobs
* maximum concurrent audio jobs
* hardware acceleration
* video encoder
* GPU memory

It does not schedule jobs or allocate resources.

Conceptually:

```text
MediaCapabilities
        ↓
PlaybackProfile
        ↓
TranscodingJob
        ↑
TranscodingCapacity
```

---

## `transcoding_job.dart`

`TranscodingJob` represents one server-side transcode prepared for playback.

It tracks:

* input path
* output path
* lifecycle status
* target playback profile
* errors

`PlaybackJobProfile` describes the concrete target output:

* video codec
* audio codec
* container
* width
* height
* bitrate

The actual transcoding process belongs to the backend transcoding service,
not these models.

---

## `media_session.dart`

`MediaSession` contains playback-session state.

It includes concepts such as:

* playback device
* current media
* playback position
* playing/paused/stopped state
* session identity

It represents session state rather than a transcoding process.

---

# User and account models

## `account.dart`

`Account` represents the account-level domain object.

It can contain:

* profiles
* shared-library information
* wishlist state
* storage information
* legal/consent state
* subscription state
* account-level preferences

Sensitive authentication material should not be exposed by ordinary public
serialization.

---

## `account_member.dart`

`AccountMember` represents an account member and role.

Supported role concepts include:

* owner
* administrator
* member

`MemberLoginRecord` contains backend authentication material such as
password hashes and must not be exposed through public account APIs.

Password hashes, MFA secrets, session credentials, and similar material
should remain inside trusted backend boundaries.

---

## `profile.dart`

`Profile` represents an individual viewing profile.

It tracks:

* owned media
* watched media
* liked/disliked media
* playback progress
* watch history
* watch-history timestamps

Profile interaction state is separate from global media identity.

---

# Ratings and reviews

## `rating.dart`

The rating model intentionally keeps external provider ratings separate.

Examples include:

* TMDB
* IMDb
* Rotten Tomatoes
* MusicBrainz
* user ratings

Provider scores are **not combined into one application-generated master
score**.

Personal profile ratings are represented separately using
`UserMediaRating`.

---

## `review.dart`

`MediaReview` represents a user's written review.

Reviews are distinct from:

* external provider ratings
* personal star ratings
* media metadata

The model supports both account-scoped/profile-scoped presentation and
global marketplace-style serialization.

---

# Groups and social playback

## `group_chat_room.dart`

Represents group chat rooms, members, and messages.

Member status and room membership are separate from the user's account
authentication state.

---

## `group_recommendation.dart`

Represents collaborative recommendations and voting.

Supported states include:

* voting
* approved
* rejected
* expired

Votes are validated against participation and voting state.

---

## `group_watch_session.dart`

Represents synchronized group playback.

It can track:

* participants
* invitations
* playback state
* playback position
* audio track
* subtitle track
* session lifecycle

The model does not itself stream media or communicate with playback
clients.

---

# Marketplace models

## `shop_entity.dart`

`ShopEntity` represents lightweight global marketplace metadata.

It is intentionally separate from private account-server content.

A marketplace entity can describe:

* an entity type
* entity ID
* display name
* subtitle
* optional external account identity
* public/private visibility

The model does **not** grant access to another server's private media.

A typical architecture is:

```text
Global marketplace metadata
        ↓
ShopEntity
        ↓
Source server/account
        ↓
Private media/content
```

The marketplace database should contain only the metadata necessary for
discovery and transactions.

---

# Subscription and payment models

## `subscription.dart`

`Subscription` represents entitlement state.

It tracks:

* plan
* start time
* expiration
* active state

The subscription model does not process payments.

---

## `payment_session.dart`

`PaymentSession` represents a payment/checkout operation.

It can track:

* plan
* amount
* currency
* payment status
* processor transaction ID
* expiration
* failure information
* checkout token

Checkout credentials and other sensitive payment/session values must not be
serialized into public API responses unless explicitly required.

---

# Remote workers and storage

## `remote_worker.dart`

`RemoteWorker` represents a trusted worker capable of performing work on
behalf of an account server.

Potential capabilities include:

* disc reading
* external optical-drive access
* ARM/import operations

Worker tokens are sensitive credentials and are excluded from normal JSON
serialization.

`RemoteImportJob` tracks the corresponding remote operation.

---

## `storage.dart`

Storage models describe infrastructure status rather than performing
storage operations.

They represent:

* individual drive status
* storage pool status
* backup status
* UPS status

These are read/status models. RAID management, filesystem operations,
backup execution, and UPS control belong to infrastructure services.

---

## `platform_capabilities.dart`

`PlatformCapabilities` represents a server/platform feature manifest.

It describes which application features are available.

It is not an authorization mechanism.

Authorization must still be enforced by backend authentication and
authorization layers.

---

# Sports models

## `sports.dart`

Sports models represent games and broadcast metadata.

A broadcast can include:

* provider
* country
* language
* commentary
* authorization state
* original-broadcast state
* stream URL
* official URL
* free-to-watch state

The presence of a URL does not by itself mean the application is
authorized to play that broadcast.

---

# Validation and serialization

Models should generally provide:

```dart
bool get isValid;
```

when lightweight structural validation is useful.

They may also provide:

```dart
factory Model.fromJson(Map<String, dynamic> json);
Map<String, dynamic> toJson();
Model copyWith(...);
```

Parsing should be defensive where API/database data may contain:

* nullable values
* numeric values represented as strings
* malformed optional fields
* missing fields from older versions

Unknown optional values should normally be ignored or normalized rather than
causing unrelated API requests to fail.

Required identity fields should still be validated by the service or
persistence layer before committing data.

---

# Identity and deduplication

A model's display title is not necessarily its canonical identity.

This is particularly important for music and physical media.

Do not deduplicate canonical recordings solely by:

```text
title
```

Where available, stronger identity signals should be used, such as:

* ISRC
* verified external recording identifiers
* audio fingerprints
* trusted metadata
* artist/release relationships
* duration and other corroborating metadata

Likewise, physical releases should not be merged merely because two releases
have the same display title.

Stable identity and merge decisions belong to the persistence/import layer.

---

# Provenance

The architecture preserves provenance so that the library can answer:

```text
Where did this media come from?
```

For physical media, provenance can flow through:

```text
Physical release
    ↓
Physical disc
    ↓
Disc content
    ↓
Media/file
```

For music:

```text
Music release
    ↓
Medium
    ↓
Track
    ↓
Canonical recording
    ↓
Stored media version
```

This allows multiple physical releases to reference the same canonical
recording while retaining the original release and rip information.

---

# Security-sensitive serialization

Models containing credentials or authentication material should make safe
serialization the default.

Examples include:

* password hashes
* MFA challenge material
* worker tokens
* checkout tokens
* session credentials

When a sensitive value must be serialized internally, the caller should
explicitly request that behavior where the model supports it.

Public API routes should never expose secrets simply because a model has a
`toJson()` method.

---

# Persistence boundary

The model layer should remain independent from the storage implementation.

Current persistence targets may include:

```text
Flutter client
      ↓
Backend routes
      ↓
Services
      ↓
Database/repository
      ↓
Models
```

For ARM/import data:

```text
Optical drive / remote worker
      ↓
ARM service
      ↓
Import review
      ↓
Library importer
      ↓
Persistence layer
      ↓
ARM/domain models
```

For playback:

```text
Media
  ↓
MediaCapabilities
  ↓
PlaybackProfile
  ↓
TranscodingCapacity
  ↓
TranscodingJob
  ↓
Playback/cache service
```

The models describe these states and contracts; they do not replace the
services responsible for executing the workflows.

---

# Compatibility

When extending an existing model:

1. Preserve existing JSON keys when possible.
2. Preserve existing constructor defaults unless the domain contract has
   intentionally changed.
3. Add new fields as optional when older persisted records may not contain
   them.
4. Make parsing tolerant of older representations.
5. Avoid silently changing the meaning of an existing field.
6. Keep sensitive fields excluded from public serialization.
7. Keep canonical identity separate from display metadata.
8. Keep physical-release provenance separate from canonical media identity.

This allows older library records and API clients to continue working while
the domain model evolves.

---

# Related backend layers

The model layer works with:

* `Backend/database/` for persistence
* `Backend/services/` for business operations
* `Backend/routes/` for HTTP/API boundaries
* `Backend/middleware/` for authentication and cross-cutting request
  controls
* `Backend/arm/` for physical-media ingestion
* `Backend/config.dart` for server configuration
* Flutter models/UI under `lib/` for client presentation

The backend remains the authoritative boundary for authentication,
authorization, persistence, media ingestion, payment processing, and
resource management.