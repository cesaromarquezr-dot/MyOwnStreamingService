# Cover Art Archive endpoint alignment

The music catalog integration was updated against the official Cover Art Archive API endpoint model.

- Read artwork metadata from `https://coverartarchive.org/release/{release-mbid}/` for an exact release.
- Read album-level artwork metadata from `https://coverartarchive.org/release-group/{release-group-mbid}/` for a release group.
- Use `/front`, `/back`, and `/front-250`, `/front-500`, or `/front-1200` only with the matching entity type and when a community-selected front image exists.
- Parse the metadata JSON's `images` array and preserve image IDs, front/back flags, types, comments, edit IDs, approval status, original URLs, and 250/500/1200 thumbnail URLs.
- Prefer the front image and approved items in the app's metadata response. Preserve the CAA metadata endpoint URL and source MusicBrainz release URL.
- A 404 is treated as “no artwork available” and returns `found: false`; it is not a missing-API-key error.
- All artwork lookup requests are made to `coverartarchive.org`. Image URLs are the URLs supplied in CAA's response, normalized to HTTPS.

No Cover Art Archive API key or secret is required. MusicBrainz release IDs and release-group IDs are different entity types; the API call must use the correct `entity` parameter. The Flutter album discography entries use `release-group` IDs, so their artwork queries use `entity=release-group` by default.

The project source has not been compiled in this environment because the Dart/Flutter SDK is unavailable. Run `dart format`, `dart analyze`, backend checks, and a manual app smoke test before deployment.
