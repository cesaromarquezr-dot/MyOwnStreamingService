# Owned Media Kiosk module

The feature's public API is exported by `kiosk.dart`. Its catalog, profile
favorites/layout preferences, owned-media repository, and kiosk screens live
in the app's shared `screens/`, `models/`, `data/`, `stores/` and `widgets/`
layers to reuse existing library and playback behavior.

This is a personal self-service interface for media already in the library.
It contains no rentals, returns, checkout, purchases or payments.
