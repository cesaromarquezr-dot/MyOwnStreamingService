-- Entertainment Studio local-first records with authenticated cloud sync.
-- Apply to staging first. All rows are owned by the Supabase auth user; the
-- client never supplies user_id. Profile-specific data carries profileId in
-- record_data and clients query that scope. Household watchlists intentionally
-- share a record type among profiles of the same authenticated account.

create extension if not exists pgcrypto;

create table if not exists public.user_entertainment_studio_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  record_type text not null check (record_type in (
    'calendar', 'journal', 'scenes', 'editions', 'watchlist',
    'subtitles', 'theories', 'presets'
  )),
  record_data jsonb not null check (jsonb_typeof(record_data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (octet_length(record_data::text) <= 16000)
);

create index if not exists idx_entertainment_studio_user_kind_updated
  on public.user_entertainment_studio_records(user_id, record_type, updated_at desc);
create index if not exists idx_entertainment_studio_data_profile
  on public.user_entertainment_studio_records using gin (record_data jsonb_path_ops);

alter table public.user_entertainment_studio_records enable row level security;
drop policy if exists entertainment_studio_owner_all on public.user_entertainment_studio_records;
create policy entertainment_studio_owner_all
  on public.user_entertainment_studio_records
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.set_entertainment_studio_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists trg_entertainment_studio_updated_at on public.user_entertainment_studio_records;
create trigger trg_entertainment_studio_updated_at
before update on public.user_entertainment_studio_records
for each row execute function public.set_entertainment_studio_updated_at();

comment on table public.user_entertainment_studio_records is
  'Private Entertainment Studio records. Row-level security restricts records to their authenticated owner. Household watchlists can be shared only among profiles using that same authenticated account; friend-group sharing requires an explicit membership/ACL design.';
