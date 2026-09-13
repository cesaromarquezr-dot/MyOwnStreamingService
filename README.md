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

## Account, server and Group Watch architecture

- One account has one managed home server in the current subscription model.
- The server owns the account's physical Movies, TV Shows and Music files; Supabase stores metadata, identity and server indexes only.
- All profiles in an account share that account's server/library, even when profiles live in different houses.
- Remote computers can be paired as import workers. A disc/import completed at a remote house is sent over a secure connection to the account's server.
- Group Chat is cross-account: rooms are coordinated by the backend and do not require shared media storage.
- Group Watch is cross-account: each participant is associated with their own account/server, and the backend validates the requested media/version on each participant server before the session starts.
- The web client is the same Flutter application compiled for web; the server-side agent/API is deployed separately on each physical media server.

## Managed-server subscription pricing

The backend calculates the public price from configurable server hardware/storage amortization, estimated electricity, bandwidth/operations, support reserve, payment processing and target gross margin. The default retail price is **$54.99 USD/month** or **$599.99 USD/year** for one managed server. Operators can change the assumptions with environment variables; the client never controls the amount charged.
