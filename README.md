# netflix

A new Flutter application.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Home server / ARM architecture

The project now treats the home server as the source of truth for server-managed media. The intended physical pipeline is:

`DVD/CD/Blu-ray/UHD drive -> ARM -> completed media -> server scanner -> database/API -> Flutter`

### Backend environment

- `SERVER_HOST=0.0.0.0` — bind the API to the LAN.
- `SERVER_PUBLIC_URL=http://<server-ip>:8080` — URL clients should use.
- `ARM_SERVER_URL=http://<arm-host>:<port>` — ARM web/API address.
- `MEDIA_ROOT=/path/to/media` — root of Movies/Series/Music storage.
- `MOVIES_PATH`, `SERIES_PATH`, `MUSIC_PATH` — optional category paths.
- `MOVIES_CAPACITY_BYTES`, `SERIES_CAPACITY_BYTES`, `MUSIC_CAPACITY_BYTES`, `AVAILABLE_STORAGE_BYTES` — dashboard capacity overrides.

The current implementation does not assume a particular physical drive or UHD firmware. Verify the exact optical-drive revision and its ARM/MakeMKV compatibility before purchasing it. Audio CDs should be routed through a CD-capable ripping workflow; the server scanner already recognizes common audio output formats.
