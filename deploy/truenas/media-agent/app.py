# TrueNAS + Supabase integration for MyOwnStreamingService

This deployment adds a read-only media gateway for movie, TV, and music files on TrueNAS. Supabase stores catalog/index metadata; TrueNAS stores the media bytes. Flutter must never receive NFS/SMB credentials or absolute NAS paths.

## Architecture

`Flutter -> existing authenticated Dart backend -> short-lived HMAC playback URL -> TrueNAS media agent -> read-only NFS/dataset mount`

The media agent looks up `server_media.relative_media_key` using `server_id` plus `server_media_id` (or `media_catalog_id`) and rejects expired/invalid signatures. It supports HTTP byte-range requests for seeking.

## 1. Prepare TrueNAS

1. Create datasets such as `tank/media/movies`, `tank/media/tv`, and `tank/media/music`.
2. Create a dedicated account with read-only access.
3. Export the media dataset over NFS to the Docker host only, or mount it on the host with the TrueNAS-supported NFS configuration.
4. Mount the dataset on the Docker host, for example `/mnt/tank/media`. Confirm the host can read files.
5. Do not expose NFS/SMB or the TrueNAS admin UI to the public internet.

## 2. Configure the gateway

1. Copy this folder to a trusted Docker host that can access the mounted dataset.
2. Copy `.env.example` to `.env` and set `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `MEDIA_AGENT_SHARED_SECRET`.
3. Use a random shared secret of at least 32 bytes. The exact same secret must be set on the Dart backend as `MEDIA_AGENT_SHARED_SECRET`. Never add either secret to Flutter or commit `.env`.
4. Set `BACKEND_HEARTBEAT_URL` to the private Dart backend URL ending in `/api/v1/server-agent/heartbeat`, and set `SERVER_ID` to the UUID of this account's existing row in `public.servers`. The agent posts a heartbeat every 30 seconds; the backend resolves the server owner in Supabase instead of trusting an account ID from the agent.
5. Edit `compose.yaml`: replace `192.168.1.60` with the Docker host's LAN IP and `/mnt/tank/media` with the actual mount path.
6. Lock down the env file: `chmod 600 .env`.
7. Start it: `docker compose up -d --build`.
8. Test `http://<LAN-IP>:8090/health` from the private LAN. The port should not be public.

The Supabase service-role key is used only inside the trusted gateway to read private server media mappings. Prefer a dedicated server-side database role with the minimum required read permissions if your deployment has one.

## 3. Configure the Dart backend

Set these environment variables on the host running `Backend/server.dart`:

- `MEDIA_AGENT_BASE_URL`: the URL reachable by playback clients, preferably an HTTPS hostname routed to the gateway, e.g. `https://media.example.com`. If using HTTPS, terminate TLS at your trusted reverse proxy and keep the origin private.
- `MEDIA_AGENT_SHARED_SECRET`: the same secret as the agent's `.env`.

Restart the backend after setting them. The backend's `MediaServerAgentService.playbackTarget` now returns a short-lived (10-minute) signed `url`, `expiresAt`, and `playbackSessionId` rather than an `agent-ready` placeholder.

## 4. Index media in Supabase

The existing `public.server_media` table already has `server_id`, `server_media_id`, `media_catalog_id`, and private `relative_media_key` fields. For every file, ensure there is a matching row where `relative_media_key` is relative to `/media`, for example:

- `movies/Dune (2021)/Dune (2021).mkv`
- `tv/Example Series/Season 01/S01E01.mkv`
- `music/Artist/Album/Track 01.flac`

Never store `/mnt/tank/media/...` in the key; never return `relative_media_key` to normal Flutter clients. The gateway resolves and checks every path stays inside `/media`.

## 5. Backend behavior and remaining integration work

The backend heartbeat route added with this integration verifies the shared secret, resolves `server_id` ownership through Supabase, and only then updates the in-memory agent snapshot. On backend restart, the agent will repopulate its snapshot on the next heartbeat (normally within 30 seconds). Do not bypass the owner check or mark every server online by default. The heartbeat endpoint is intended for the trusted private LAN; do not expose it without network controls and rate limiting.

The agent currently supports direct file streaming and byte ranges. It does not transcode, generate HLS/DASH, extract subtitles, or normalize codecs. For broad TV/console compatibility, use a media server/transcoder such as Jellyfin behind an equally secure authorization integration.

## Security notes

- Use HTTPS outside the trusted LAN; do not publish port 8090 directly to the internet.
- Keep the Supabase secret/service-role key only on trusted servers.
- The playback URL is a bearer capability until expiry; do not log full query strings or share URLs.
- Restrict reverse-proxy routes, rate-limit playback creation, and use account/profile entitlement checks before issuing URLs.
- Review TrueNAS ACLs and test access with the dedicated read-only identity.
