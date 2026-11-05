# Shared Media Experience module

The feature's public API is exported by `media_experience.dart`. Canonical
models, repository/API adapter, state store, screens, renderer helper and
presentation widgets are kept in the shared app layers so movie, episode,
music and collection details can reuse the same playback integration.

The case/disc presentation currently uses Flutter perspective transforms.
The packaged GLB geometry is valid but is not yet loaded by a live GLB scene
renderer; see `assets/3d/README.md`.
