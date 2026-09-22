# Database

Contains the backend persistence abstraction and database migrations for accounts, sessions, media, groups, reviews, ratings, ARM ingestion metadata, and marketplace associations.

## Persistence responsibilities

The database layer provides storage and access for:

* Accounts, profiles, sessions, authentication state, and account preferences.
* Media-library records and playback-related metadata.
* Groups, group memberships, recommendations, watch activity, and reviews.
* External/provider rating snapshots.
* Private profile-specific media ratings.
* ARM ingestion jobs and physical-media provenance.
* Physical releases, discs, and individual disc contents.
* Canonical music recordings and their relationships to music releases/tracks.
* Lightweight global marketplace entity associations.

## Ratings

External ratings and personal profile ratings are intentionally stored separately.

Provider ratings are cached snapshots containing information such as:

* Provider name.
* Rating type.
* Rating value and scale.
* Vote count when available.
* Source URL.
* Last update time.

Profile ratings represent an individual profile's personal 0.5-to-5-star rating in half-star increments.

Provider ratings, profile ratings, and public reviews are not combined into a single score.

## ARM and physical-media provenance

ARM ingestion preserves the distinction between a physical release and the media contained on it.

The persistence model can represent:

```text
Physical Release
└── Physical Disc
    └── Disc Content
        └── Library Media
```

This allows a release to contain multiple discs and allows a disc to contain multiple independent pieces of content.

For example, a bonus-features disc can contain:

* Deleted scenes.
* Trailers.
* Commentaries.
* Interviews.
* Featurettes.
* Other supplemental material.

Bonus content remains associated with the physical disc without being incorrectly represented as the primary movie or show.

The database also preserves the original disc/release provenance so imported library media can be traced back to its physical source.

## Music identity

Music releases and canonical recordings are separate entities.

A release may contain tracks that reference the same canonical recording found on another release:

```text
Artist Album
└── Track → Recording A

Soundtrack
└── Track → Recording A
```

The same recording therefore does not need to become a duplicate canonical song merely because it was discovered on another physical release.

Recording identity should be established using reliable identifiers and metadata such as:

* ISRC.
* Audio fingerprint.
* Verified metadata.
* Other provider or catalog identifiers.

A title alone should not automatically merge two recordings.

## Marketplace associations

The global marketplace database stores only lightweight entity metadata.

It may associate entities such as:

* Movies.
* Shows.
* Music releases.
* Recordings.
* Artists.
* Collections.
* Other supported marketplace entities.

Physical media and private library files remain on the owning account's server.

The global marketplace association index is therefore not a replacement for the account's local media database. It provides a discoverability/association layer that can later support privacy and public-visibility controls.

## Local versus global data

The architecture separates account-server data from global marketplace metadata:

```text
Account Server
├── Media files
├── Library metadata
├── Physical release/disc provenance
├── ARM jobs
├── Profile ratings
└── Private account data

Global Marketplace
└── Lightweight shop entity associations
```

Credentials, passwords, API keys, and media files are not stored in the global marketplace association index.

## Migrations

SQL migration files in this directory define durable database structures.

Migrations should:

* Be safe to run against an existing installation where practical.
* Avoid storing secrets or media files.
* Preserve existing account and library data.
* Keep external ratings separate from personal ratings.
* Preserve physical-media provenance.
* Avoid automatically merging distinct media solely because their titles match.
* Keep global marketplace metadata separate from private account-server media.

The in-memory database implementation may be used for local development and tests, while the durable database/store implementation is responsible for production persistence.
