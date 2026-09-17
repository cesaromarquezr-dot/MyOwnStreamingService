# Home server backend

The Dart backend exposes the authenticated API used by Flutter. `arm/` contains ARM integration, `routes/` contains HTTP endpoints, `services/` contains business logic, `models/` contains API/domain objects, and `database/` contains the current persistence abstraction.

For a physical deployment, mount the media disks and optical drives into the ARM/server environment and configure the ARM URL and media paths through environment variables.

## Account/server deployment model

The production architecture is one managed home/media server per account in the current subscription tier. Profiles can live in different houses and still use the same account server remotely. Each physical server deployment uses the same server-side code but is registered to its account; the Flutter/web client is not installed as the server itself.

Group Chat is central/backend coordination and can contain profiles from different accounts. Group Watch is also cross-account: the backend resolves invited profiles, validates media availability/authorization on each participant account's server, and synchronizes playback state without moving the physical media into central storage.

## Storage subsystem

The backend treats NAS storage as a first-class subsystem. See `docs/STORAGE_ARCHITECTURE.md` for HDD/SSD tiers, RAID availability, backups, UPS behavior, and the authenticated `/api/v1/storage/system` endpoint.

## Storage subsystem

Storage is a first-class subsystem. See `docs/STORAGE_ARCHITECTURE.md` for HDD/SSD tiers, RAID availability, backups, UPS behavior, and the authenticated `/api/v1/storage/system` endpoint.

## Automated media pipeline additions

The backend now treats ARM as the automated media-ingestion layer. ARM is designed to monitor configured optical drives, scan complete discs, enumerate every title/track, preserve the physical-release relationship, and produce a separate library import plan for every detected entertainment item. Metadata fields can carry artwork, posters, descriptions, cast, artist, album, release/market information, and region data.

Music imports prefer **FLAC** as the lossless archive/master representation. Lossless masters are retained while playback-specific AAC/MP3/Opus/etc. versions are derived only when a device requires them.

Playback transcoding uses a bounded concurrent scheduler. Set `TRANSCODE_MAX_CONCURRENT` to control the number of simultaneous ffmpeg jobs. Direct Play and remuxing remain preferred so the server does not spend CPU/GPU resources on unnecessary conversions.

Recommendations include country/language and adaptation-group relationships so verified international/local productions can be surfaced as related works. Shop/Merchandise eligibility is represented separately from entertainment metadata and must be backed by a real merchant/product relationship.
