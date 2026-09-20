# Project Improvements – September 2026

## Implemented in this review build

### Marketplace navigation
- Navbar Shop remains the global marketplace.
- Details, Music, and Collection Shop actions open a contextual marketplace scoped to the exact entertainment entity.
- Contextual pages never fall back to unrelated global products.
- The Create Store button disappears after the current account owns an active store.
- Seller Dashboard is shown in the navbar only while the current account owns an active store.
- Main navigation listens for Shop catalog changes so Seller Dashboard appears immediately after store creation.
- Checkout returns to the existing Shop route after purchase instead of replacing the application's route stack.

### Remembered devices and sessions
- The client creates a random persistent device identifier and stores it in encrypted device storage.
- Device type/name are sent during login and recorded in Supabase.
- Session tokens remain encrypted on the device.
- Supabase stores only a SHA-256 session-token hash, never the raw session token.
- After a backend restart, the client can ask the backend to rehydrate the session from the hashed Supabase record.
- A valid restored session goes directly to profile selection; it does not require the first welcome/login flow again.
- Profile customization remains keyed to the selected profile, so a previously configured profile does not repeat first-time customization.
- Device type is metadata, not authentication by itself.

### Disc import/review
- The existing ARM review workflow remains the approval gate.
- Each detected title displays its disc title, media type, classification, edition/cut when supplied, and ripped filename such as `movie.mkv`.
- Multiple movies on one disc remain separate review entries.
- Alternate cuts/editions can share one library movie card while retaining separate source files.
- Selecting Play on a movie with multiple imported versions asks which version to watch.
- TV episode titles can be grouped into one show with seasons and episodes.
- Season pages expose episode ranges/counts and preserve per-episode source file, audio, subtitle, language, and extra metadata.
- Music/CD imports display album, artist, song title, and runtime and can populate the music track catalog when ARM supplies those fields.

## Recommended next improvements

1. Connect real metadata providers through provider interfaces and cache provider snapshots separately.
2. Store provider-specific ratings independently (IMDb, Rotten Tomatoes, TMDB, MusicBrainz, user ratings) rather than merging scores.
3. Add a formal `media_versions` client model tied to the existing Supabase `media_versions` table so editions/cuts are first-class rather than inferred from title/year.
4. Add real carrier APIs for shipping quotes. Seller package weight/dimensions should be required before a live quote is requested.
5. Persist Shop catalog, carts, orders, seller settings, and product images in Supabase instead of local-only SharedPreferences.
6. Add artwork/cast/director/writer provenance and refresh timestamps so metadata can be refreshed without overwriting user edits.
7. Add import reconciliation that detects duplicate titles, alternate editions, incomplete seasons, missing episodes, missing artwork, and unmatched extras before approval.
8. Add a per-item media manifest showing the exact source file, checksum, codec, resolution, HDR format, audio tracks, subtitle tracks, chapters, extras, and storage location.
9. Add profile-scoped playback preferences for audio/subtitle/version choice and remember them per show/movie.
10. Add device/session management so users can see, rename, trust, revoke, and sign out individual devices.
