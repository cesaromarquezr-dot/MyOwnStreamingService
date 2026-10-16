# MyOwnStreamingService — discovery and artist/music features

## Included in this patch

- Artist/band hub opened from the existing Music > Artists section.
- Artist hub sections: owned songs, owned discography, local listening popularity, local music videos, tracks featuring the artist, and related artists seeded from shared track credits.
- Album selection opens a track list of the tracks actually present in the local indexed library.
- Player display selector for audio visualizer, lyrics + visualizer, and a matching music video when `MusicTrack.musicVideoUrl` is populated.
- Retailer search links on movie/TV details for Amazon, Walmart, Mercado Libre Mexico, and eBay. These open title search results; they do not claim a specific item is in stock or that a digital store grants in-app playback rights.
- Supabase migration tables for external media catalog metadata, retailer offers, artist/album metadata, related artists, and worldwide chart entries. A mirrored migration is provided under `lib/supabase/migrations/`.

## Apply

1. Back up your working project and merge the patch files into the matching paths.
2. Apply `Backend/database/discovery_catalog.sql` to the Supabase database. The identical migration is mirrored at `lib/supabase/migrations/discovery_catalog.sql`.
3. Deploy a trusted backend ingestion job/Edge Function that fills `external_media_catalog`, `external_media_offers`, `music_artist_metadata`, `music_album_metadata`, `music_artist_relations`, and `music_chart_entries` from metadata/chart/retailer providers whose terms allow the intended use. The client deliberately has read-only RLS policies for these tables.
4. Ensure your NAS media scanner maps each imported track's local music-video URL into `MusicTrack.musicVideoUrl` where a matching local video exists. The field is optional; missing videos remain disabled.
5. Run `flutter pub get`, `dart format lib/music.dart lib/details.dart`, `flutter analyze`, and your existing tests locally.

## Important current limitations

- Worldwide popular song rankings need a chart data provider and ingestion. Until that is connected, the artist page explicitly shows local listening popularity rather than inventing a worldwide ranking.
- Fans Also Like currently uses shared track/collaboration credits as a starter relationship graph. Provider-based audience similarity can populate `music_artist_relations` later.
- Retailer buttons perform title searches. They are not a verified stock/price aggregator. Verified offers should be inserted into `external_media_offers` by the trusted backend with region and verification timestamps.
- The external catalog schema is groundwork; the current library recommendation widget still ranks titles already known to the app. A catalog ingestion + recommendation endpoint is required before external-only titles can appear automatically in actor-based recommendations.
- Lyrics are shown only when authorized/local lyric text is present. Do not scrape or distribute copyrighted lyrics without appropriate rights.
- The Flutter/Dart SDK was unavailable in the editing environment, so `flutter analyze` and runtime tests were not run here.
