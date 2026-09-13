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
