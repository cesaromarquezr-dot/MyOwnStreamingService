# Server selection save fix

This patch addresses the server selection screen appearing to do nothing after the user saves a display name.

## Changes

- Shows a progress overlay while the server assignment is being saved.
- Applies a 30-second timeout to the claim call and preserves the error instead of immediately clearing it via a refresh.
- After a timeout/error, rechecks server context in case the backend committed the assignment but the response was lost.
- Logs unexpected server-route failures to the backend console while returning a safe error message to the client.
- The mock launcher explicitly enables `PLATFORM_SERVER_MOCK=true`. If the Supabase catalog is empty/unavailable in mock mode, seeded `local-server-*` records can be claimed in memory. Production startup sets this flag to false, so synthetic server IDs cannot be assigned in a persistent deployment.

## Apply

Extract the patch into the project root, preserving the `lib/` and `Backend/` subfolders. Restart the backend with `Backend/start_mock.ps1` and restart Flutter. In mock mode, a successful Save should open profile selection. For a persistent deployment, apply the platform-server migrations and ensure the account mapping exists before using real Supabase server IDs.
