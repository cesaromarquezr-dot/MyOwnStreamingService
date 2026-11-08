# Virtual Store 3D renderer

The Virtual Store now uses `flutter_scene` to render a real 3D room with perspective camera, floor and perimeter walls, multiple aisle racks, repeated physical media cases, wall-mounted poster frames, a collection-box gallery, a CD/playlist listening lounge, and the project's existing GLB case/collection models. The owned-library browser remains the source of truth for opening a selected title or collection.

## Platform requirements

- `flutter_scene: 0.24.3` requires Flutter 3.47 or newer.
- Android already enables Flutter GPU in `AndroidManifest.xml`.
- Windows already enables Flutter GPU in `windows/runner/main.cpp`.
- iOS and macOS now opt in through `FLTEnableFlutterGPU` in their `Info.plist` files.
- Web uses the package's WebGL2 backend and does not need the native flag.

Run `flutter pub get`, `flutter analyze`, and `flutter run` on the target device. On native desktop, use Flutter 3.47.1 or newer for release builds.

The scene is procedurally assembled, so it does not require downloading external 3D models. Existing GLB models are used for the entrance case display and physical collection gallery, with procedural geometry as a fallback if an optional GLB fails to load.
