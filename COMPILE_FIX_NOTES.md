# Compile fix update

This package includes fixes for the analyzer diagnostics reported on 2026-10-31:

- `lib/details.dart`: use `AppController.instance.isOwned(media.id)` for the details ownership indicator.
- `lib/music_lyrics_search_screen.dart`: await `Completer.future.timeout(...)` rather than calling `timeout` on the Completer.
- `lib/navigation_hubs.dart`: route Collections through `LibraryCollectionsScreen`, import `backend_api.dart` so `BackendApiLibraryMethods` is available, and retain the scheduled-library additions loader.
- `lib/hey_media.dart`: remove the unused `dart:convert` import.
- `lib/watch_hub.dart`: keep all `WatchHubMode` values, including `library`, exhaustively handled with a widget returned in each case.
- `lib/core/services`: include only the canonical `disc_ingestion_service.dart`; no duplicate `(2)` copy is included.

Jellyfin, Shop, and Food Delivery remain removed from the saved source snapshot. This package does not reintroduce Jellyfin callbacks or pages.

## After extraction

1. Restore your own local `.env` files and any development certificates from secure backups; they are intentionally not bundled.
2. Run `flutter pub get` from the project root.
3. Run `flutter analyze` from the project root.

Flutter/Dart was not available in the packaging environment, so this archive has not been validated by running `flutter analyze` here.
