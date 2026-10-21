-- MyOwnStreamingService: fix PostgREST PGRST204 for profiles.governance.
-- Safe to run repeatedly. Adds the profile governance JSONB column without
-- changing existing profile records or access policies.

begin;

alter table public.profiles
  add column if not exists governance jsonb not null default '{}'::jsonb;

comment on column public.profiles.governance is
  'Profile content/admin policy. Never store raw profile PINs here.';

-- Ask PostgREST/Supabase to refresh the schema cache.
notify pgrst, 'reload schema';

commit;
