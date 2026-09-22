-- FILE: `lib/supabase/migrations/music_customization.sql`.
-- Purpose: Adds the per-profile Music page customization snapshot.
--
-- Security:
-- This extends the existing profile-scoped customization snapshot.
-- Physical audio, music, disc, and other media files are never stored here.
--
-- The existing RLS policy on profile_customization_snapshots continues to
-- control access based on the owning profile/account.

alter table public.profile_customization_snapshots
  add column if not exists music_configuration jsonb not null default '{}'::jsonb;

comment on column public.profile_customization_snapshots.music_configuration is
  'Profile-scoped Music page customization state. Physical audio and other media files are never stored here.';