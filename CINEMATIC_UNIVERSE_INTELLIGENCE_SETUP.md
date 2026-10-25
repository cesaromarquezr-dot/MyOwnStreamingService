# Cinematic Universe Intelligence setup

This feature replaces the browse pages' curated title-by-title filmographies with metadata-driven catalog groups and adds live upcoming-title discovery.

## Configure TMDB

1. Create an API key in your own TMDB account and comply with TMDB attribution/usage requirements.
2. Build/run Flutter with `--dart-define=TMDB_API_KEY=YOUR_TMDB_API_KEY`.
3. Open **Franchises** or **Cinematic Universes** and select **Cinematic Universe Intelligence**. It refreshes on opening, offers a manual refresh, and refreshes every 12 hours while that screen is open.

Do not commit a shared API key into source control. For production, proxy metadata requests through your backend so the key is not distributed in the client.

## What it does and does not infer

- Discovers upcoming movies and TV shows dynamically using TMDB production-company metadata, deduplicates the same TMDB title returned by multiple studio rules, and shows release dates, posters, overview, and studio signals.
- Existing franchise/universe catalog groups remain metadata-driven through the app's existing `franchiseName`, `franchiseNames`, `universeMemberships`, and continuity fields.
- Studio overlap is not proof of shared story continuity. A studio can make unrelated projects, and some shows may not have complete production-company metadata. Verify relationship metadata before automatically merging a title into a cinematic universe.
- The app does not silently create local library records from discovered upcoming titles. Provider discovery is a candidate feed; adding titles to the actual catalog should require an explicit metadata/import workflow.
- Refresh runs when the screen opens and periodically while it is open. Mobile operating systems may suspend an app in the background; guaranteed background updates require a backend scheduled job/push mechanism.

The provider API key is required for live discovery. Without it, the app can still display the universe/franchise groups already represented in its local catalog metadata.


## Starter examples and Cast & Crew enrichment

The intelligence screen includes a short, explicit set of Marvel movie/show examples to validate provider matching. It is not a complete or authoritative hand-maintained filmography. The list demonstrates movie-vs-show handling and marks `Spider-Noir` as a separate continuity instead of silently adding it to the MCU.

When a title's Details page opens and `TMDB_API_KEY` is configured, the app searches TMDB using the local title and media type, uses the year as a matching hint where available, and requires an exact normalized title match before loading `/credits`. Cast, characters, directors, writers and music are merged with existing local credits without replacing them. Credits are merged into the existing in-memory catalog record and the privacy-controlled offline metadata cache; no new library item is created and no playback URL is changed. A manual refresh icon is also available in Cast & Crew.

Example title lookups are available from **Franchises / Cinematic Universes → Cinematic Universe Intelligence → Starter examples**. The preview displays the metadata returned by TMDB and does not add a media file or automatically assert franchise continuity.

TMDB title/credit results depend on provider coverage, correct local titles, and API availability. For production deployments, prefer a backend proxy so the API key is not distributed in the client; comply with TMDB's current attribution and API terms.
