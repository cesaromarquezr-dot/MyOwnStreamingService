# Procedural GLB assets

These are small, valid glTF 2.0 binary geometry assets for the reusable physical-media experience. They use simple original cuboid/cylinder meshes and neutral materials. Artwork, title, edition, and format labels are supplied by the library at runtime rather than baked into the models.

- `cases/`: DVD, Blu-ray, steelbook, CD, vinyl, and TV-season cases.
- `collections/`: multi-title collection/box-set containers and playlist boxes.
- `kiosk/`: kiosk carousel housing and disc geometry.

The current app widgets provide a portable Flutter perspective fallback. The GLB assets are packaged by `pubspec.yaml`, but the full interactive GLB scene renderer is not yet active.
