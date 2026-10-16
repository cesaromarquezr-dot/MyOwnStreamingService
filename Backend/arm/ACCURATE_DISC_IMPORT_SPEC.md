# Accurate DVD / Blu-ray / UHD / CD Import Requirements

## Goal

A physical disc import must preserve the content and technical choices encoded on the disc. A disc is a physical container, not a media identity. The same series can be imported from any disc in any order without changing its canonical episode order.

## Required workflow

1. **Identify the physical release** — read available barcode/catalog identifiers, disc label, region, edition, disc number, and drive information. Keep the retail release identity separate from individual media identities.
2. **Enumerate every disc title/playlist/track** — do not select only the largest title and discard the rest. Retain source title IDs/playlist IDs and source disc positions as provenance.
3. **Inspect media structure** — record durations, chapter markers, video/audio/subtitle streams, stream languages, codec/profile, audio channels, default/forced flags, hearing-impaired/visual-impaired flags, and labelled commentary tracks.
4. **Classify every content item** — primary movie, TV episode, deleted scene, trailer, commentary title, making-of, interview, music video, audio track, menu/data item, or unknown. A title name is only a hint; low-confidence results must be reviewed.
5. **Extract selected content** — preserve all selected audio and subtitle tracks. Prefer a source-preserving remux when supported. Transcoding is an explicit optional choice, not an accidental side effect.
6. **Verify per output file** — check file existence, decodability, expected stream types, duration, and expected chapters when a trusted expected value is available. Attach verification and track inventory to the content item it actually describes.
7. **Match canonical metadata** — resolve title/series/season/episode identities, editions, and bonus-feature relationships. Preserve original disc titles and embedded metadata beside corrected/localized metadata.
8. **Review ambiguous items** — require confirmation when an episode number, series identity, edition, or extra classification is uncertain. Failed/unresolved items must not be silently published as regular library episodes.
9. **Import idempotently** — an interrupted/retried import must not create duplicate episodes or overwrite an existing edition. Track physical release, disc, content, canonical media, media version, and server file IDs independently.

## TV episode identity and watch order

The canonical episode identity contains a series identity, season number, episode number, optional end episode for multi-episode titles, optional absolute number, episode title, order scheme, confidence, and match source.

- Physical disc number and rip/import order are never used as episode season/order.
- The default playback order should use the series' selected numbering scheme (normally aired order). DVD order and absolute order may be offered when the chosen metadata source supports them.
- Specials may belong to Season 0. Multi-part episodes may span an episode range. Remakes, specials, pilot versions, split episodes, and different editions must remain distinguishable.
- Multiple discs from one set join the same canonical series/season, even if Disc 3 is imported first.
- A strong `S01E02`, `1x02`, or `Season 1 Episode 2` pattern can suggest an order, but filename/title parsing alone is not proof of canonical identity. The current parser deliberately flags pattern-only matches for review. A trusted episode metadata match or user confirmation raises its confidence.
- Unresolved episodes stay in a review queue. They must not be assigned by physical disc index or by the order in which titles are discovered.
- Watch progress is keyed to the canonical episode/media ID, not to the source disc or filename, so progress survives file renames, alternate editions, and re-imports.

## Movies and bonus features

- A movie feature, alternate cut, trailer, deleted scene, interview, making-of, and commentary stream are distinct concepts.
- Extras should be linked to the related movie or series and appear in an **Extras / Bonus Features** area, not as unrelated main-library movies.
- Chapter markers provide file-level scene selection when the output container preserves them. A standalone MKV normally does **not** retain the disc's original interactive DVD/Blu-ray menu. If preserving the original menu navigation is required, provide a separate disc-archive mode that stores the full supported disc structure when the installed toolchain permits it and local law allows it.
- An audio commentary track is usually an alternate audio stream on the feature, not a separate video title. Keep it as a selectable audio track when present. A separately authored commentary title can also be represented as bonus content.
- Blu-ray playlists can contain duplicate, alternate, or decoy playlists. Use source playlist identifiers, title duration, stream layout, fingerprints, and trusted release data to identify duplicates; do not blindly rip every playlist as a different movie.

## Music discs

- Audio CD imports should use an audio-CD-capable workflow, preserve track order and multi-disc numbers, and default to a lossless archive format such as FLAC when that is the user's choice.
- Preserve album/artist/track tags, language where available, artwork reference, release identifiers, ISRC where available, and gapless sequencing information. Fingerprinting can assist duplicate detection but should not replace review of ambiguous matches.
- Movie soundtracks, live concerts, music videos, and studio albums should be related where appropriate without merging distinct recordings just because their names match.

## Language and metadata rules

- Store original track language identifiers and labels. Do not infer a stream's language from its position (for example, Track 1 is not automatically English).
- Record every subtitle stream detected in the extracted output, including forced and accessibility flags. A stream omitted during ripping cannot be recovered by the verifier; the ripper must select it before extraction.
- Preserve original disc labels and embedded title/tag text. Store normalized titles and translations as additional values; never overwrite artist names, franchise names, original titles, codec labels, or other proper/technical values with machine translations.
- Keep source/provider IDs, match confidence, and match source to support audits and manual correction.

## Current code in this patch

- Adds a canonical episode identity with a season/episode order key.
- Parses common explicit episode-number patterns, without using the disc number, and sorts resolved entries independently from import order.
- Flags title-pattern-only episode matches for review; a user-confirmed metadata-provider episode match can be attached during import review. Import approval is blocked for episodes still missing a confirmed canonical identity.
- Improves content classification so clear bonus labels do not automatically become primary movies/episodes.
- Adds per-title verification attachment where ARM reports an exact output file; refreshes the physical-disc content snapshot so the per-title inventory follows the reviewed entry.
- Saves ffprobe-derived video/audio/subtitle inventory and chapter markers into verification JSON, including language tags, audio commentary labels, codec, channels, default/forced and accessibility flags where the output exposes them. The app-facing `Media` model can retain this structured inventory as well as legacy display labels.
- Chooses a content-aware verifier type for movie, TV, and music jobs rather than always requiring video. Season and episode cards are numerically sorted by their canonical metadata fields, not by import/disc order. Commentary can be audio-only, and album content is kept distinct from individual tracks.

## Integration still required before claiming end-to-end hardware correctness

The metadata provider adapter must supply trustworthy series/episode candidates (including season/episode numbers and provider IDs), and the ARM/ripper adapter must expose all relevant playlists/titles/tracks and exact output paths. The current code does not itself prove that every physical drive, protected disc, firmware combination, menu structure, or ripper configuration exposes every stream. Test with representative DVDs, Blu-rays/UHDs, multi-disc TV sets, and audio CDs on the actual home-server hardware. Respect applicable copyright and access-control laws.
