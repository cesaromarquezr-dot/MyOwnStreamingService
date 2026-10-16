# Streaming Experience Implementation

## Included in this release

- `lib/streaming_experience.dart` adds a profile-scoped playback/accessibility preference screen, an adaptive URL player for media records that contain an authorized `playbackUrl`, and a bounded device-local Quality of Experience (QoE) event log.
- `lib/app_core.dart` accepts the optional `playbackUrl`/`streamingUrl` metadata field. It must be an HTTPS URL supplied by an authenticated playback gateway or a short-lived signed media URL. Never store a raw TrueNAS path or embed a Supabase service-role key in the Flutter client.
- `lib/player.dart` uses the adaptive stream player when a valid HTTP(S) `playbackUrl` is supplied. Otherwise it retains the current YouTube trailer preview behavior. It also reads the per-profile autoplay preference.
- `lib/main.dart` exposes **More → Streaming Experience** for playback/accessibility preferences and device-local diagnostics.
- `lib/smart_search.dart` adds bounded typo tolerance and searches more media metadata fields. Recommendation relevance is now a tie-breaker only after the query actually matches, avoiding unrelated recommended titles appearing for every query. The Home recommendation fallback ranks in-library candidates using server recommendations when available, plus likes, unfinished watch progress, shared genres/credits/tags/franchises, ratings, and recency; disliked and completed titles are excluded. This is a transparent local relevance heuristic, not a trained ML model.
- The Home **Music & Film** section now renders a **Continue Listening** rail for tracks with playable media URLs, ranks previously listened tracks, promotes the current track, and resumes/pauses the current music session when its card is tapped.
- `scripts/encode_hls_ladder.sh` builds a compatible H.264/AAC HLS VOD ladder (1080p, 720p, 480p) in a separate output directory without modifying the source.
- `Backend/database/streaming_experience_telemetry.sql` (mirrored under `lib/supabase/migrations/`) creates service-role-only tables for QoE events, discovery feedback, and profile preferences.

## Current limitations—do not mistake scaffolding for live infrastructure

1. The client adaptive player can play a URL only when a trusted service has already supplied it. The current `/api/v1/playback/prepare` route performs safe direct-play/remux/transcode preparation but does not yet mint a signed HLS master-manifest URL from a library item ID. The NAS media gateway must resolve catalog IDs server-side, validate profile access, and return an expiring playback URL before this becomes an end-to-end NAS streaming flow.
2. The settings screen stores a maximum-resolution and data-saver preference per profile/device. The selected cap affects stream quality only once the trusted playback gateway applies it to its HLS variant list or transcode decision; the Flutter video plugin cannot uniformly select a bitrate across every platform on its own.
3. Subtitle-size/audio-description preferences are persisted. Applying them requires a selected subtitle renderer or platform/player track-selection support for the stream supplied to each device. The current player continues to rely on the native `video_player`/platform capabilities.
4. QoE diagnostics are currently local to the device (maximum 500 events). The SQL migration intentionally exposes no authenticated-client policies because this project uses application account/profile IDs rather than assuming they are Supabase Auth UUIDs. A trusted API/Edge Function must validate account/profile ownership and insert telemetry using the service role before cross-device dashboards can be enabled.
5. The script creates VOD HLS renditions, not a full live TV pipeline and not DRM. Run it in an FFmpeg-enabled container with the source library mounted read-only and a separate writable output directory. Validate media you own or are authorized to process.

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

Review `Backend/database/streaming_experience_telemetry.sql` against the live schema, then apply it using your normal migration process. These tables intentionally deny direct access to `anon` and `authenticated`; do not add broad client write policies. Implement and test a trusted endpoint with profile ownership checks before wiring remote telemetry or preference synchronization.
