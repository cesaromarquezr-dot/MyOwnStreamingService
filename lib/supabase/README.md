# Supabase database

This project uses Supabase for persistent **application state**, not for the physical media library.

## Storage architecture

* Movies, TV episodes, music, CDs/discs, and other media files stay on each account's home server.
* `media_catalog` describes canonical media identity only.
* `server_media` is the per-server index of what the server owns.
* `media_versions` identifies the exact edition, cut, or version.
* `relative_media_key` is server-private and must never be exposed to normal clients.
* Group Watch checks every participant's server for the exact same `version_key` before allowing a session.

## Flutter configuration

The Flutter application uses the public Supabase client. Configure the Supabase project URL and publishable key at build time:

```text
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The legacy `SUPABASE_ANON_KEY` environment variable is also accepted as a fallback during migration:

```text
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

The Supabase URL must be the project URL. Do not append `/rest/v1/`.

Never put a Supabase service-role key in the Flutter application.

## Apply migration

Run:

```text
supabase/migrations/202609120001_streaming_service.sql
```

in the Supabase SQL editor or through the Supabase CLI.

The migration creates the account/profile/server hierarchy, server media indexes, exact-version Group Watch procedures, reviews, recommendations/votes, UI settings, security, remote jobs, backups, sports, legal tables, triggers, RLS, and scheduled jobs.

## Flutter → Supabase synchronization

The Flutter application initializes the public Supabase client for read/client features, but the current account authentication system is the application's own authenticated backend session.

Protected account writes are therefore sent through the Dart backend rather than exposing a Supabase service-role key to Flutter.

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

The Flutter `AppController.syncCurrentAccountToSupabase()` function sends a sanitized account snapshot to:

```text
POST /api/v1/supabase/sync/account
```

The backend authenticates the user, strips sensitive authentication material, and writes the snapshot using `SupabaseStore`.

Physical movie, TV, music, disc, and other media files are never uploaded to Supabase.

Only application metadata and non-file state are synchronized, including:

* account and profile state
* storage information
* wishlist/media identifiers
* notifications
* application preferences
* reviews and other application state
* other metadata required by the streaming-service application

The home server remains responsible for the physical media files and their server-private storage paths.
