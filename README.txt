MyOwnStreamingService UI navigation patch

Replace these files in your Flutter project:
- lib/main.dart
- lib/home_streaming_discovery.dart

Changes:
- Removes the Explore tab from the Home top browse row.
- Removes the Explore bottom-sheet action and its now-unused callback.
- Removes Watch from the bottom navigation bar and NavigationRail.
- Keeps Home, Friends, More, and Profile navigation working.
- Leaves LibraryHubScreen and playback functionality in the codebase; this patch only removes the Watch navigation destination.

Validation:
- Basic delimiter balance checked.
- Flutter/Dart analyzer was not available in this environment, so run `flutter analyze` in your project after applying.
