# Music Top 10 integration

This patch wires music Top 10 rankings into the existing app and backend.

## Included changes

- `Backend/services/music_catalog_service.dart`
  - Adds public ListenBrainz sitewide weekly charts for artists, release groups (albums), and recordings (songs).
  - Uses a 30-minute in-memory cache and the last successful result as a temporary stale fallback.
  - Uses MusicBrainz identifiers and Cover Art Archive URLs when the chart provides identifiers.
  - Does not require a Spotify API key or ListenBrainz API key.
- `Backend/routes/music_catalog_routes.dart`
  - Adds the authenticated `GET /api/v1/music-catalog/global-charts` endpoint.
- `lib/backend_api.dart`
  - Adds the authenticated client method for global music charts.
- `lib/weekly_top10.dart`
  - Connects Global Top 10 for singers, bands, albums, and songs to ListenBrainz.
  - Renders Global, This Profile, and Account Top 10 panels together, using three columns on wide screens and fewer columns on smaller screens.
  - Keeps Profile Top 10 local to the active profile, using the profile's saved play-start counters plus completed-play records.
  - Keeps Account Top 10 aggregated from completed music activity synced for the account's profiles, subject to existing profile governance rules.
  - Explains when a ranking is empty and which activity is counted.

## Setup

No `LISTENBRAINZ_API_KEY` or Spotify API credentials are required for Global Top 10. A valid contact User-Agent **is required** by ListenBrainz, so configure `MUSIC_METADATA_USER_AGENT` in `Backend/.env` before expecting Global charts to load. Example:

```env
MUSIC_METADATA_USER_AGENT="MyOwnStreamingService/1.0 (you@example.com)"
```

Replace the example with your real contact email or a contact URL; do not leave the placeholder. `Backend\run.ps1` reads `Backend/.env` into the backend process, so edit the existing `.env` file (not just `.env.example`) and then restart the backend. The backend serializes ListenBrainz requests at 1.05-second intervals to stay under its one-call-per-second rule.

## Ranking definitions and limitations

- **Global** uses ListenBrainz sitewide community listening statistics. These are listens contributed to ListenBrainz, not a complete measurement of all listeners or streams across every music service.
- **Albums** are ranked from ListenBrainz release-group statistics; **songs** from recording statistics; **artists** from artist statistics.
- ListenBrainz does not expose a matching sitewide genre Top 10 endpoint here, so Global Music Genres remains unavailable. Profile and Account Music Genres continue to be derived from track genre metadata.
- The current separate Singer/Band shelves infer solo-versus-group classification from credited names. This heuristic is approximate; names alone cannot always identify an artist's MusicBrainz entity type.
- Profile music rankings count track starts stored in that profile's local music preferences and reconcile them with completed playback records. Account rankings currently aggregate completed playback records synced to the account, so an offline or unfinished play may appear in Profile but not Account until completion and sync.
- MusicBrainz and Cover Art Archive were already part of the project; this patch reuses them for metadata identifiers and artwork. Spotify remains an optional catalog provider, not a dependency for these charts.

## After replacing files

From the project root:

```powershell
cd Backend
.\run.ps1
```

In another PowerShell window, from the project root:

```powershell
flutter analyze
```
