# Music metadata APIs: Spotify, MusicBrainz, and Cover Art Archive

This update adds a searchable online music metadata catalog to the existing Music destination. Open **Music** and use the new Music Catalog card or library/music toolbar icon to search artists, albums, songs/recordings, and open a MusicBrainz artist's discography.

## Provider roles

- **Spotify Web API**: search metadata for artists, albums, and tracks. This integration uses server-to-server Client Credentials; the client ID and client secret are read only by the backend. Spotify metadata does not grant audio playback rights. Music playback still needs a personal media server or another licensed playback provider.
- **MusicBrainz**: source for artist identities, release groups (album-level releases), recordings, and artist discographies. It does not currently require an API key for ordinary read searches. Requests identify this application with `MUSIC_METADATA_USER_AGENT` and are serialized to honor the MusicBrainz one-request-per-second rule.
- **Cover Art Archive**: provides community-sourced release and release-group artwork, with graceful empty-artwork handling when no cover exists. It does not require an API key for these read endpoints.
  - Release artwork uses `https://coverartarchive.org/release/{release-mbid}/`; album-level artwork uses `https://coverartarchive.org/release-group/{release-group-mbid}/`. The `/front`, `/back`, and `front-250`, `front-500`, or `front-1200` variants are available where the archive has selected that image.
  - The app requests metadata from `coverartarchive.org`, then displays the image/thumbnail URL returned by the archive. A missing image is a normal `found: false` result, not a provider configuration error.

## Setup

1. Create or select an app in the Spotify developer dashboard and copy its Client ID and Client Secret.
2. Copy `Backend/.env.example` to `Backend/.env` if it does not already exist. Set:

   ```dotenv
   SPOTIFY_CLIENT_ID=your_spotify_client_id
   SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
   MUSIC_METADATA_USER_AGENT="MyOwnStreamingService/1.0 (self-hosted)"
   ```

3. Keep those Spotify values in **`Backend/.env` only**. Do not put the Spotify client secret in the Flutter root `.env`, Flutter assets, `--dart-define`, or a source file. The repository's `Backend/run.ps1` imports backend environment variables before starting the Dart API server.
4. Restart the backend after changing `Backend/.env`, then sign in to the app and open **Music → Music Catalog**.
5. If Spotify credentials are not configured or Spotify rejects the app, MusicBrainz remains usable and the screen displays provider notes. Configure `BACKEND_API_URL` in the Flutter root `.env` to point to your HTTPS backend `/api/v1` base as usual.

## Backend endpoints

All endpoints require a valid MyOwnStreamingService backend session.

- `GET /api/v1/music-catalog/status`
- `GET /api/v1/music-catalog/search?q=Radiohead&type=all&limit=10`
- `GET /api/v1/music-catalog/discography?mbid=<musicbrainz-artist-mbid>&limit=100`
- `GET /api/v1/music-catalog/cover-art?mbid=<musicbrainz-release-or-release-group-mbid>&entity=release-group` (use `entity=release` for a release MBID; use `entity=release-group` for an album-level release-group MBID). The response includes the archive's listing, `thumbnail250`, `thumbnail500`, `thumbnail1200` when available, and the source MusicBrainz release URL.

Supported search types are `all`, `artist`, `album`, `track`, and `recording`. Spotify search is capped at 10 results per category/request to align with the current Web API search limit. MusicBrainz lookup traffic is rate-limited by the backend queue.

## Spotify developer-mode constraints

Spotify's current February 2026 Web API migration guide states that Development Mode requires the app owner to have an active Spotify Premium subscription, limits new Development Mode apps to five authorized users, and sets the search endpoint's maximum `limit` to 10. Spotify also removed/changed some other endpoints and response fields, so this integration intentionally uses search metadata rather than old browse/new-release/top-track features. See the current [Spotify migration guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide) and [Client Credentials documentation](https://developer.spotify.com/documentation/web-api/tutorials/client-credentials-flow).

## Validation status

This is a source integration. The editing environment does not have the Dart/Flutter SDK, so run `dart format`, `dart analyze`, and the app/backend locally before deploying. Verify that `Backend/.env` remains untracked and that no real secrets are committed or shipped inside the Flutter assets.
