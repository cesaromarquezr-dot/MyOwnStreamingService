# Original-language audio and subtitle defaults

## Behavior

- Streaming Experience preferences now default to **Prefer original-language audio and subtitles** enabled. The setting is stored per profile on the device.
- The language policy uses explicit title/franchise overrides first, then `MediaItem.originalLanguage`, then `MediaItem.language`, and finally `countryOfOrigin` when its language is reasonably unambiguous.
- The named Korean examples (`Parasite`, `Parasitos`, `Gisaengchung`, and `Squid Game`) default to Korean.
- The named Mexican animated titles (`La Leyenda de la Nahuala`/`Nanahuala`, `La Leyenda de la Llorona`, `La Llorona`, `Momias de Guanajuato`, `Chupacabras`, and `Charro Negro`) default to Spanish.
- James Bond films in the known 25-film series and recognizable Marvel films/franchises default to English.
- Other titles use available catalog language metadata and country-of-origin fallback rather than a hard-coded list of nationalities.
- If a matching track is available in `MediaItem.audioTracks` or `MediaItem.subtitles`, the player/details selection defaults to it. If it is unavailable, the policy selects a reasonable existing fallback and never invents a track. Subtitle enablement remains a separate profile preference and defaults to on, as it did previously.
- The user can override the current audio or subtitle choice in the existing options UI or turn off the original-language preference in Streaming Experience settings.

## Important playback-engine limit

The current `AdaptiveStreamingPlayer` uses Flutter's `video_player` controller, which does not expose cross-platform audio/subtitle track-selection APIs in this project. The updated policy chooses the default values used by the app's existing track-selection UI and surfaces the resolved default on the details page. It cannot force an arbitrary external HLS/DASH manifest or an already-generated signed playback URL to switch tracks by itself. To guarantee actual track changes for every adaptive stream, the gateway/player pipeline must expose language-tagged track selection or the app must adopt a playback engine with track-selection support. The code intentionally does not pretend a metadata label change proves the underlying stream switched.

## Metadata recommendation

Prefer storing ISO-639-1 codes (`en`, `es`, `ko`, etc.) in `originalLanguage`, plus explicit `countryOfOrigin`, `audioTracks`, and `subtitles` metadata. A real track label should include a human-readable language or ISO-639 code, e.g. `Korean (5.1)`, `Spanish`, or `eng`, for matching to work reliably. Country is only a fallback; multi-country co-productions should use the catalog's original-language field.
