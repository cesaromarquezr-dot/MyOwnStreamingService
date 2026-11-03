# Streaming Experience Implementation

## Included in this release

- `lib/streaming_experience.dart` adds a profile-scoped playback/accessibility preference screen, an adaptive URL player for media records that contain an authorized `playbackUrl`, and a bounded device-local Quality of Experience (QoE) event log.
- `lib/app_core.dart` accepts the optional `playbackUrl`/`streamingUrl` metadata field. It must be an HTTPS URL supplied by an authenticated playback gateway or a short-lived signed media URL. Never store a raw TrueNAS path or embed a Supabase service-role key in the Flutter client.
- `lib/player.dart` uses the adaptive stream player when a valid HTTP(S) `playbackUrl` is supplied. Otherwise it retains the current YouTube trailer preview behavior. It also reads the per-profile autoplay preference.
- `lib/playback_queue_store.dart` and `lib/playback_queue.dart` provide a persistent, reorderable queue for library media and imported music tracks. Queue entries store profile-scoped IDs only; the queue can be saved as a private collection and/or music playlist. Playback progress continues to use the existing profile/account sync queue.
- `lib/main.dart` exposes **More → Streaming Experience** for playback/accessibility preferences and device-local diagnostics.
- `lib/smart_search.dart` adds bounded typo tolerance and searches more media metadata fields. Search can be refined by mood tags, genre, original language, release era, runtime (when explicit runtime metadata is available), and unwatched status; music results use their available genre, duration, and listening-history metadata. Recommendation relevance is a tie-breaker only after the query actually matches, avoiding unrelated recommended titles appearing for every query. The Home recommendation fallback is a transparent local relevance heuristic, not a trained ML model.
- `lib/dialogue_search.dart` adds authenticated home-server subtitle indexing and dialogue search. The backend accepts only matching video sidecars in `.srt` or `.vtt` format, bounds scan size, returns relative media IDs and cue timestamps (never subtitle file paths), and the UI filters results by profile access before offering playback seek.
- The Accessibility & Offline settings expose presence and activity-sharing controls. Turning either setting off requests that current shared presence/activity be cleared before persisting the local preference; failures are surfaced so users know server-side cleanup may not have completed.
- The Playback & Server Health page links to the existing non-destructive Library Protection Center for duplicate review and sanitized library export. Existing profile accessibility controls, local backup/restore, and privacy preferences remain the source of truth rather than parallel implementations.
- The Home **Music & Film** section now renders a **Continue Listening** rail for tracks with playable media URLs, ranks previously listened tracks, promotes the current track, and resumes/pauses the current music session when its card is tapped.
- `scripts/encode_hls_ladder.sh` builds a compatible H.264/AAC HLS VOD ladder (1080p, 720p, 480p) in a separate output directory without modifying the source.
- `Backend/database/consolidated_platform.sql` (mirrored under `lib/supabase/migrations/`) creates service-role-only tables for QoE events, discovery feedback, and profile preferences.

## Current limitations—do not mistake scaffolding for live infrastructure

1. The client adaptive player can play a URL only when a trusted service has already supplied it. The current `/api/v1/playback/prepare` route performs safe direct-play/remux/transcode preparation but does not yet mint a signed HLS master-manifest URL from a library item ID. The NAS media gateway must resolve catalog IDs server-side, validate profile access, and return an expiring playback URL before this becomes an end-to-end NAS streaming flow.
2. The settings screen stores a maximum-resolution and data-saver preference per profile/device. The selected cap affects stream quality only once the trusted playback gateway applies it to its HLS variant list or transcode decision; the Flutter video plugin cannot uniformly select a bitrate across every platform on its own.
3. Subtitle-size/audio-description preferences are persisted. Applying them requires a selected subtitle renderer or platform/player track-selection support for the stream supplied to each device. The current player continues to rely on the native `video_player`/platform capabilities.
4. QoE diagnostics are currently local to the device (maximum 500 events). The SQL migration intentionally exposes no authenticated-client policies because this project uses application account/profile IDs rather than assuming they are Supabase Auth UUIDs. A trusted API/Edge Function must validate account/profile ownership and insert telemetry using the service role before cross-device dashboards can be enabled.
5. The script creates VOD HLS renditions and does not implement DRM. Run it in an FFmpeg-enabled container with the source library mounted read-only and a separate writable output directory. Validate media you own or are authorized to process.
6. The playback queue is local to the selected profile/device and contains IDs only. Queue changes do not currently synchronize across devices. A missing runtime field is treated as unknown and is excluded when a runtime filter is selected.
7. Dialogue search currently indexes `.srt`/`.vtt` sidecars stored beside video files. Its bounded index is held in backend memory per authenticated account, is lost when the backend restarts, and must be rebuilt from **More → Connected Command Center → Search Dialogue**. It does not yet index embedded subtitle tracks, remote subtitle providers, or transcripts; timestamps are seekable only for media the selected profile can play.

## Adaptive delivery pipeline

1. Import/read source media from TrueNAS without modifying originals.
2. Probe codecs, duration, audio tracks and subtitles; queue a background FFmpeg worker.
3. Generate aligned 1080p/720p/480p HLS renditions and validate every manifest and segment.
4. Register a server-side media ID-to-manifest mapping. Do not return absolute filesystem paths to clients.
5. Serve manifests/segments through an authenticated or short-lived signed gateway over HTTPS. Configure CORS and MIME types for web clients, cache immutable segments, and restrict manifest/token TTLs appropriately.
6. Return a signed manifest URL as `playbackUrl` alongside a media item only after checking authenticated account, selected profile, playback rights, region/parental settings, and subscription state.
7. Capture startup-ready time, buffering duration, seek events, errors and completion. Compare results by device class and network type before tuning the ABR ladder.

## Suggested validation targets

These are initial project goals, not guarantees: median player-ready under 2 seconds; investigate startup over 4 seconds; minimize rebuffer ratio and fatal errors; test on actual iOS/Android, Safari, Chromium, Windows/macOS/Linux desktop and intended TV hardware. HLS support differs by operating system/browser: use a suitable native implementation for supported targets and an HLS/DASH-capable web player such as Shaka Player or hls.js where browser-native support is absent.

## Apply the Supabase schema

Review `Backend/database/consolidated_platform.sql` against the live schema, then apply it using your normal migration process. These tables intentionally deny direct access to `anon` and `authenticated`; do not add broad client write policies. Implement and test a trusted endpoint with profile ownership checks before wiring remote telemetry or preference synchronization.
