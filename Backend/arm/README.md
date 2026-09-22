# ARM integration

Contains the client, service, verification, title-resolution, physical-media
and import-review boundaries used to communicate with Automatic Ripping Machine
(ARM).

ARM integration is modeled as a complete ingestion pipeline:

```text
Drive discovery
    ↓
Whole-disc scan
    ↓
Multi-title enumeration
    ↓
Physical release / edition identification
    ↓
Disc identification
    ↓
Disc-content classification
    ↓
Metadata / artwork / description / cast enrichment
    ↓
Import plan
    ↓
Integrity verification
    ↓
Safe repair / recovery
    ↓
Import review / approval
    ↓
Playable library version
```

## Physical media model

ARM does not treat an optical disc as a movie by itself.

The ingestion model preserves the physical provenance hierarchy:

```text
Physical release
└── Physical disc
    ├── Main feature
    ├── Bonus feature
    ├── Deleted scenes
    ├── Commentary
    ├── Trailer
    ├── Music
    ├── Data
    └── Other content
```

A physical release may contain multiple discs:

```text
Movie Collector Edition
├── Disc 1
│   └── Main Feature
├── Disc 2
│   └── Main Feature
├── Disc 3
│   └── Bonus Features
└── Disc 4
    └── Soundtrack
```

The physical release and physical disc IDs are provenance identifiers. They
describe what was physically scanned or ripped and do not replace the
identity of the individual media contained on those discs.

### Disc content

A disc can contain multiple independent content items.

For example, a DVD might contain:

```text
Spider-Man DVD
└── Disc 1
    ├── Main Feature
    ├── Deleted Scenes
    ├── Commentary
    └── Theatrical Trailer
```

The main movie is therefore represented as the primary feature while the
deleted scenes, commentary and trailer remain separate disc-content records.

Bonus material must not be converted into fake movie records merely because
it is stored in a video container.

The disc-content layer supports content classifications including:

* feature
* episode
* bonus feature
* music
* data
* other

This allows the normal library to expose the primary movie or episode while
retaining the complete physical-disc provenance and bonus material.

## Multi-disc releases

A release containing multiple discs is represented as one physical release
with multiple physical discs.

```text
PhysicalRelease
├── id
├── title
├── releaseType
├── edition
├── barcode
└── discs[]
```

Each disc contains its own contents:

```text
PhysicalDisc
├── id
├── releaseId
├── discNumber
├── title
├── discType
├── region
└── contents[]
```

This means a four-disc movie collection does not become four unrelated
editions merely because ARM processes each physical disc separately.

The persistence layer can use release identifiers, barcode information,
edition metadata and other verified identifiers to associate separately
scanned discs with the same physical release.

## Music releases and canonical recordings

Music uses a separate distinction between a **release** and a
**recording**.

A release represents a particular physical or catalogued publication:

```text
MusicRelease
├── title
├── artist
├── releaseType
└── mediums[]
```

A medium contains tracks:

```text
MusicMedium
├── mediumNumber
├── title
└── tracks[]
```

A track points to a canonical recording:

```text
MusicTrack
├── trackNumber
├── title
├── artist
├── recordingId
└── outputPath
```

The canonical recording represents the underlying recording identity:

```text
MusicRecording
├── id
├── title
├── artists[]
├── duration
├── ISRC
└── audioFingerprint
```

This prevents the same recording from becoming duplicated merely because it
appears on multiple releases.

For example:

```text
Artist album
└── Track
    └── Recording A

Movie soundtrack
└── Track
    └── Recording A
```

Both releases can therefore reference the same canonical recording.

The ingestion order does not define the identity:

```text
Album first
    ↓
Recording A created

Soundtrack later
    ↓
Track matched to Recording A
```

or:

```text
Soundtrack first
    ↓
Recording A created

Album later
    ↓
Track matched to Recording A
```

The persistence layer is responsible for resolving whether a candidate is an
existing recording or a new recording. Track title alone must not be treated
as sufficient identity because different performances, edits, remasters,
live recordings and mixes can share a title.

Where available, strong identifiers such as ISRC and verified audio
fingerprints should be used to improve recording identity resolution.

## Lossless music preservation

ARM recognizes audio/lossless metadata and prefers FLAC as the preserved
lossless archive/master format when the source and workflow support it.

The original lossless source remains the archival representation.

Playback formats are derived later by the playback capability layer rather
than replacing the preserved source:

```text
Lossless archive/master
        ↓
Playback capability layer
        ↓
Compatible playback/transcode format
```

This keeps archival quality separate from device-specific playback
requirements.

## Metadata enrichment

ARM title information is only the starting point for library ingestion.

The metadata boundary can enrich imported material with:

* canonical title
* original title
* original language
* country of origin
* year
* media type
* release/edition information
* artwork/poster
* description
* cast
* external identifiers
* music artist/album/track information
* recording identifiers

Metadata providers remain behind the provider-neutral metadata service
boundary so that the ARM ingestion pipeline is not coupled to one external
provider.

Provider results are candidates for review and identity resolution; they are
not automatically treated as authoritative merely because a title matched.

## Title resolution

Title resolution normalizes ARM-discovered titles into canonical library
metadata while preserving the original disc title.

The model therefore retains both:

```text
Original disc title
        +
Canonical title
```

This is important for localized releases, alternate editions and discs whose
printed or machine-detected title differs from the canonical library title.

No real-world title aliases are hard-coded into the generic ARM integration
layer. Alias and identity mappings should come from verified metadata,
configuration or persistence data.

## Import review

ARM imports pass through an explicit review boundary before becoming trusted
library content.

The review process can contain:

```text
ARM result
    ↓
Metadata candidates
    ↓
Selected metadata
    ↓
Verification result
    ↓
Physical release/disc/content association
    ↓
Recording identity when applicable
    ↓
Approval
    ↓
Library import
```

The approval decision records the selected metadata and relevant physical
media identities.

For music, the approval can additionally reference the canonical recording
identity.

For bonus material, the approval retains its disc-content identity instead
of forcing the content into a primary movie or episode record.

## Verification

Verification is performed against the actual imported content rather than
only against metadata.

Video verification can check:

* output existence
* video stream
* audio stream
* duration
* chapter count
* expected stream counts
* supported container/codec information
* full decode integrity

Music verification can check:

* output existence
* audio stream
* duration
* codec/container information
* lossless characteristics where applicable
* decode integrity

Data and other non-media content can use structural verification instead of
requiring video or audio streams.

A verification failure prevents the item from being treated as a completed
library import.

## Repair and recovery

The ARM boundary is intended to support safe recovery of incomplete or
failed imports.

Verification results identify the failing content and preserve diagnostic
metadata so the import workflow can decide whether the content should be:

* retried;
* repaired;
* re-ripped;
* returned for metadata review;
* rejected.

A failed verification must not silently become a playable library version.

## Import provenance

Imported files retain their physical provenance wherever possible:

```text
Physical release
    ↓
Physical disc
    ↓
Disc content
    ↓
Ripped output
    ↓
Library media
```

This makes it possible to answer questions such as:

* Which release did this movie come from?
* Which physical disc contained this bonus feature?
* Which disc produced this ripped file?
* Which soundtrack release contained this track?
* Which canonical recording does this track represent?
* Was this item verified before it entered the library?

The normal media library can remain clean and user-friendly while the
physical-media model retains the detailed provenance required for archival
and re-import workflows.

## Mock ARM

`MockArmService` provides a deterministic Phase 1 ARM simulation for
development and verification when physical ARM hardware is unavailable.

It is enabled only through:

```text
ARM_MOCK=true
```

The mock follows the same lifecycle as production ARM:

```text
queued
  ↓
detecting
  ↓
ripping
  ↓
verifying
  ↓
readyForReview
```

It also exercises the physical-media hierarchy rather than returning only a
single movie title.

The simulated disc includes:

```text
Mock Disc Movie
└── Disc 1
    ├── Mock Disc Movie
    ├── Mock Deleted Scenes
    └── Mock Theatrical Trailer
```

This allows development and automated verification to exercise:

* physical release creation;
* physical disc creation;
* primary feature classification;
* bonus-feature classification;
* trailer classification;
* disc-content relationships;
* verification;
* successful review readiness;
* rejected verification paths.

The mock does not introduce real-world metadata aliases or external provider
assumptions.

## Production boundary

The ARM client is intentionally isolated from the production library
persistence layer.

The main responsibilities are:

```text
ArmClient
    ↓
ArmService
    ↓
ArmDisc / ArmDiscTitle
    ↓
Physical release / physical disc / disc content
    ↓
Metadata service
    ↓
Verification
    ↓
Import review
    ↓
Library importer
    ↓
Persistent library
```

This separation allows the application to use:

* a real ARM installation;
* the deterministic mock ARM service;
* different metadata providers;
* different persistence implementations;

without changing the conceptual library model.

ARM is therefore treated as an ingestion source rather than as the identity
system for the entire media library.

```
```
