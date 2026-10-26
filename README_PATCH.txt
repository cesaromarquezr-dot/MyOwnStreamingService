OWNERSHIP-AWARE RECOMMENDATION FIX

Overlay this patch at the root of your MyOwnStreamingService project, preserving the lib/ and docs/ folders. It updates the TMDB recommendation and mood shelves, the local related-title shelf, and the Details page ownership check used to suppress purchase links for titles already in the active profile's library.

Then run:
  flutter pub get
  flutter analyze
  flutter test

A Flutter SDK was not available when this patch was prepared, so the analyzer and tests must be run in your local environment.
