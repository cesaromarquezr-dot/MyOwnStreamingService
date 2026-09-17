# ARM integration
Contains the client, service, verification and title-resolution boundary used to communicate with Automatic Ripping Machine.

ARM integration is intentionally modeled as a full ingestion pipeline: drive discovery -> whole-disc scan -> multi-title enumeration -> edition/release metadata -> artwork/poster/description/cast enrichment -> import plan -> integrity verification -> safe repair/recovery -> playable library version.

A disc containing multiple independent titles produces multiple independent library records. Physical release/disc IDs remain shared provenance rather than becoming one incorrectly bundled movie.

For music, ARM recognizes audio/lossless metadata and prefers FLAC as the preserved lossless archive/master format. Playback transcodes are derived later by the playback capability layer.
