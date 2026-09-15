-- FILE: `lib/supabase/migrations/music_customization.sql`.
-- Purpose: Adds the per-profile Music page customization snapshot.
-- Physical audio/media files are never stored here.

alter table public.profile_customization_snapshots
  add column if not exists music_configuration jsonb not null default '{}'::jsonb;
