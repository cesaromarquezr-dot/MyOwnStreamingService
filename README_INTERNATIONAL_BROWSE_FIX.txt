MyOwnStreamingService — International Browse & Original Title Fix

What changed
------------
- International catalog examples are tagged as `international-catalog` and stay in the app's normal local browse catalog.
- Home now has visible “International Movies” and “International Shows” shelves near the top, before the large hero banner. These shelves are independent of the optional Movies/TV Shows home-section toggles.
- Movies, TV Shows, and Film each have a dedicated, clearly labeled international rail at the top of the screen, in addition to the normal catalog list.
- The Movies and TV Shows screens prioritize international catalog examples in Default sort, so they do not sit behind a long existing library.
- The Film experience prioritizes international entries and no longer truncates its Movies and TV Shows lists to the first 12 records.
- Movie/show title surfaces bypass automatic phrase translation, including the TV-show feature cards, Film hero, collection title prompt, and group-watch invite sentence. Existing cached translations do not alter the catalog title display.
- TMDB exact-title normalization now retains non-Latin letters instead of stripping Korean/Japanese/Chinese scripts to an empty string. TMDB metadata/test output also prefers original-language title fields.
- Original display labels remain exactly as curated, including “Una película de huevos”, “Candidato Honesto”, “La leyenda de la Nahuala”, “기생충”, “부산행”, and “오징어 게임”.
- These catalog examples are metadata previews only. They do not include video files and are not playable until a real media source is added. TMDB poster/details enrichment still requires a configured TMDB API key and an exact provider match.

Install notes
-------------
1. Extract this project ZIP.
2. Copy your existing private `.env` into the project root, or configure the same variables locally. The ZIP intentionally excludes `.env` so credentials are not redistributed.
3. Run `flutter pub get`, then `flutter run` for your target platform.
4. Rebuild/relaunch the app from this extracted source project (downloading a ZIP does not update an already-installed app).
5. Open Home, Movies, TV Shows, and Film. Confirm the international shelves appear and the display titles remain unchanged.

Validation status
-----------------
The source edits and curated title references were statically checked in the package. A Flutter/Dart SDK was not available in the editing environment, so `dart format`, analyzer, and Flutter runtime tests could not be run here. See `test/international_catalog_visibility_test.dart` for the new catalog checks.
