MyOwnStreamingService — consolidated source package

This is a complete source package assembled from the latest project archive
and the saved file patches available in this conversation. It includes the
Shop/Food Delivery startup and navigation cleanup, Explore/Watch navigation
changes, the saved lyrics and music Top 10 updates, and the compile/removal
fixes listed below.

Current cleanups in this package

- Jellyfin has been removed from the More menu, Streaming Upgrade Center,
  connection/plugin screens, and Personal Media Server choices. Existing
  unknown saved server choices migrate back to the built-in service.
- The dedicated Friends primary page and navbar destination have been removed.
  Home-based friend stories and separately used community/chat components are
  preserved; this does not delete every social feature.
- The Shop and Food Delivery initializers/callbacks are removed from startup
  and the main More sheet. Unused legacy source files are retained where other
  library/social code still references their shared models.
- The missing _asksForLatestAlbum intent matcher is restored. The existing
  _latestAlbumReply implementation is preserved.
- PrimaryDestination now keeps Home and Library cases exhaustive; the Library
  destination remains available internally, but no Watch navbar item is added.
- ListenBrainz Global music Top 10 and related backend/client source patches
  are included from the saved project updates.

Install / use

1. Back up your current project folder before replacing anything.
2. Extract this archive as a separate project folder first and inspect it.
3. Restore your own root .env and Backend/.env from a secure backup; they are
   intentionally excluded from this archive because they may contain secrets.
4. Backend/certs development keys are excluded. Regenerate local development
   certificates if your Backend setup uses them.
5. Run `flutter pub get`, then `flutter analyze` from the project root. Run the
   Backend's normal dependency/install and test steps separately.

Validation limitation

Flutter and Dart are not installed in the package-building environment, so I
could not run flutter analyze here. The saved archive's watch_hub.dart is an
older compatible version where WatchHubScreen returns LibraryHubScreen(),
whose constructor in this same archive does not require onRefresh/showAppBar.
Your latest local watch_hub.dart that produced those two analyzer errors was
not available in the saved project files, so compare that file before replacing
an active working copy. This archive is based on the latest complete project
snapshot saved in the Library, not a live copy of your Windows working folder.
