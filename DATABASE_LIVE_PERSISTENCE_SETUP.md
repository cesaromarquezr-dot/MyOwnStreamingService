# Live database persistence setup

The backend is now designed to keep Supabase as the durable metadata database while the user's actual movie/TV/music files remain on the user's own home server.

## 1. Apply the database migrations

In Supabase SQL Editor, run the existing base schema first:

`lib/supabase/migrations/streaming_service.sql`

Then run:

`lib/supabase/migrations/live_persistence.sql`

The second migration adds stable application IDs, a backend-only credential table, profile customization storage, and a safer `server_media -> media_catalog` delete relationship.

## 2. Configure the backend's Supabase connection

The backend reads these values from the home-server process environment:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

The service-role key must only exist on the backend/home server. Never put it in Flutter code, `--dart-define` values shipped to the client, source control, or a public ZIP.

Example PowerShell setup for a development machine:

```powershell
[Environment]::SetEnvironmentVariable('SUPABASE_URL', 'https://YOUR-PROJECT.supabase.co', 'User')
[Environment]::SetEnvironmentVariable('SUPABASE_SERVICE_ROLE_KEY', 'YOUR_SERVICE_ROLE_KEY', 'User')
```

Close and reopen the terminal after setting persistent Windows environment variables.

## 3. Start the backend

```powershell
cd "C:\Users\cesar\VS Projects\streaming_service_ui\Backend"
dart run server.dart
```

The backend loads persisted accounts from Supabase on startup.

## What is persisted

### Accounts
Signup writes the account metadata and the Argon2id password hash. The plaintext password is never stored.

### Login
The backend reloads the account and Argon2id hash from Supabase after a server restart, so the account can still authenticate. Active login sessions remain server-memory state and are intentionally not restored after a restart.

### Profiles
Create, update and delete operations are persisted as real `profiles` rows. Profile deletion cascades profile-owned database state.

### Home server
Each account gets one `servers` row and a storage row. Media rows reference the account's server.

### Media
A home-server scan creates/updates real `media_catalog` and `server_media` rows. Only metadata/index information is stored in Supabase. Physical media files remain on the account's home server.

### Media deletion
The new media DELETE API removes the database index entry only. It does not delete the physical home-server file. Physical file deletion remains a separate storage operation.

### Media metadata editing
Title, year, description, poster, trailer and metadata can be updated without changing the physical media file.

### Profile UI
Home, Details and platform customization snapshots can be synchronized into `profile_customization_snapshots`.

## Security model

The Flutter application never receives the service-role key. Backend access to the credential table uses the service-role connection, and the credential table intentionally has no client RLS policy.

Password storage uses Argon2id hashes. The actual media files and private server paths are not uploaded to Supabase.
