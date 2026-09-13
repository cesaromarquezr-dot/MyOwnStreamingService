# Streaming Service Architecture Notes

## Account and server ownership

- Each account is associated with its own home/media server in the current one-server-per-account subscription model.
- Profiles belong to accounts, not servers. Profiles may be used from any physical location.
- The account server is the source of truth for that account's physical Movies, TV Shows and Music files.
- Supabase stores identity, metadata, server indexes and coordination state; it does not store the physical media files.

## Remote importing

A browser cannot directly control a computer's optical drive. The intended flow is:

`Disc -> local Media Importer/ARM -> secure Internet transfer -> account server -> server scanner -> website library`

The existing remote-worker API is the coordination layer. A production deployment still needs the local importer process that performs the actual disc read/rip and transfers the completed output.

## Cross-account Group Chat

Group Chat is backend-coordinated and is independent of media storage. A room can contain profiles from multiple accounts.

## Cross-account Group Watch

The Group Watch invitation UI accepts local profiles plus usernames/emails from other accounts. The backend resolves cross-account identifiers and the GroupWatchService verifies that each participant's account is authorized for the requested media before the session is created.

The synchronized session carries playback state (play/pause/position and local audio/subtitle choices). Physical video files remain on the authorized account servers.

## Pricing

Default managed-server pricing is `$54.99 USD/month` or `$599.99 USD/year` for one server.

The backend pricing floor is calculated from configurable assumptions:

- $650 server hardware amortized over 36 months
- $180 storage amortized over 36 months
- 45 W average server power
- $0.16/kWh electricity
- $6/month bandwidth/operations reserve
- $4/month support reserve
- 3.5% + $0.30 payment-processing allowance
- 25% target gross margin

The retail price is never accepted from the client; the backend calculates the payment amount.

## Validation

The available container does not include the Dart or Flutter executables, so `dart format` and `flutter analyze` could not be run here. The edited source was checked for the intended changes and the output archive is structurally valid.


## Flutter to Supabase data synchronization

- Flutter initializes Supabase with the public publishable key for client-side Supabase features.
- Protected account synchronization uses the existing authenticated backend session.
- `Backend/routes/supabase_sync_routes.dart` exposes `POST /api/v1/supabase/sync/account`.
- `Backend/supabase_store.dart` writes a sanitized account snapshot using the server-only `SUPABASE_SERVICE_ROLE_KEY`.
- `AppController.syncCurrentAccountToSupabase()` is the Flutter entry point for uploading application metadata.
- Login performs a best-effort synchronization, and storage-request code synchronizes after a successful request.
- The service-role key must never be placed in Flutter, web assets, mobile builds, or desktop client configuration.
- Physical media remains on the account's home server and is never uploaded to Supabase.
