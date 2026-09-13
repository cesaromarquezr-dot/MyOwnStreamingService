# Supabase database

This project uses Supabase for persistent **application state**, not for the physical media library.

## Storage architecture

- Movies, TV episodes, music, CDs/discs and other media files stay on each account's home server.
- `media_catalog` describes canonical media identity only.
- `server_media` is the per-server index of what the server owns.
- `media_versions` identifies the exact edition/cut/version.
- `relative_media_key` is server-private and must never be exposed to normal clients.
- Group Watch checks every participant's server for the exact same `version_key` before allowing a session.

## Flutter configuration

Provide the Supabase project URL and anon/publishable key at build time:

```text
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

Never put a Supabase service-role key in Flutter.

## Apply migration

Run `supabase/migrations/202609120001_streaming_service.sql` in the Supabase SQL editor or through the Supabase CLI.

The migration creates the account/profile/server hierarchy, server media indexes, exact-version Group Watch procedures, reviews, recommendations/votes, UI settings, security, remote jobs, backups, sports, legal tables, triggers, RLS and scheduled jobs.


## Flutter -> Supabase synchronization

The Flutter application initializes the public Supabase client for read/client features, but the current account authentication system is the application's own authenticated backend session. Therefore, protected account writes are sent through the Dart backend rather than exposing a Supabase service-role key to Flutter.

Configure Flutter with:

```text
--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co
--dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Configure the backend/home server with:

```text
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

The Flutter `AppController.syncCurrentAccountToSupabase()` function sends a sanitized account snapshot to `POST /api/v1/supabase/sync/account`. The backend authenticates the user, strips sensitive authentication material, and writes the snapshot using `SupabaseStore`.

Physical movie, TV, music, disc, and other media files are never uploaded to Supabase. Only application metadata, account/profile state, storage information, wishlist/media identifiers, notifications, and other non-file state are synchronized.
